/// لایهٔ presentation فقط UseCase صدا می‌زند (بخش ۲۴.۵ — Riverpod 2+).

library;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/network_providers.dart';
import '../../../../../core/localization/locale_provider.dart';
import '../../../../../core/student/selected_grade_provider.dart'
    show progressionStoreProvider;
import '../../../../../core/student/student_directory.dart';
import '../../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/remote/student_management_mock_datasource.dart';
import '../../data/datasources/remote/student_management_remote_datasource.dart';
import '../../data/repositories_impl/student_management_repository_impl.dart';
import '../../domain/entities/student_entities.dart';
import '../../domain/repositories/student_management_repository.dart';
import '../../domain/usecases/get_ai_report_usecase.dart';
import '../../domain/usecases/get_student_detail_usecase.dart';
import '../../domain/usecases/get_students_usecase.dart';
import '../../domain/usecases/promote_student_usecase.dart';
import '../../domain/usecases/send_password_reset_usecase.dart';
import '../../domain/usecases/soft_delete_student_usecase.dart';
import '../../domain/usecases/update_student_status_usecase.dart';

// ── DI (بخش ۲۴.۷) ──────────────────────────────────────────────────────────
/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final studentMgmtDataSourceProvider =
    Provider<StudentManagementRemoteDataSource>((ref) {
  if (kUseLiveBackend) {
    return StudentManagementRemoteDataSourceImpl(ref.watch(apiClientProvider));
  }
  return StudentManagementMockDataSource(
      localeCode: ref.watch(localeProvider).languageCode);
});

final studentMgmtRepositoryProvider = Provider<StudentManagementRepository>(
    (ref) => StudentManagementRepositoryImpl(
        ref.read(studentMgmtDataSourceProvider)));

final getStudentsUseCaseProvider = Provider(
    (ref) => GetStudentsUseCase(ref.read(studentMgmtRepositoryProvider)));
final getStudentDetailUseCaseProvider = Provider(
    (ref) => GetStudentDetailUseCase(ref.read(studentMgmtRepositoryProvider)));
final getAiReportUseCaseProvider = Provider(
    (ref) => GetAiReportUseCase(ref.read(studentMgmtRepositoryProvider)));
final updateStatusUseCaseProvider = Provider((ref) =>
    UpdateStudentStatusUseCase(ref.read(studentMgmtRepositoryProvider)));
final softDeleteUseCaseProvider = Provider(
    (ref) => SoftDeleteStudentUseCase(ref.read(studentMgmtRepositoryProvider)));
final sendPasswordResetUseCaseProvider = Provider(
    (ref) => SendPasswordResetUseCase(ref.read(studentMgmtRepositoryProvider)));
final promoteStudentUseCaseProvider = Provider(
    (ref) => PromoteStudentUseCase(ref.read(studentMgmtRepositoryProvider)));
final demoteStudentUseCaseProvider = Provider(
    (ref) => DemoteStudentUseCase(ref.read(studentMgmtRepositoryProvider)));

// ── State ──────────────────────────────────────────────────────────────────
final studentListFilterProvider =
    StateProvider<StudentListFilter>((ref) => const StudentListFilter());

/// دفترچهٔ شاگردان (منبع واحد حقیقت حساب‌ها) — تا راجستر شاگرد جدید یا
/// تغییر وضعیت حساب، خودکار لیست مدیر را تازه کند.
final studentDirectoryProvider = ChangeNotifierProvider<StudentDirectory>(
    (ref) => StudentDirectory.instance);

final studentsProvider = FutureProvider<PagedStudents>((ref) async {
  // با هر تغییر واقعی (راجستر شاگرد جدید، ارتقای صنف/پیشرفت) بازسازی شود.
  ref.watch(studentDirectoryProvider);
  ref.watch(progressionStoreProvider);
  final filter = ref.watch(studentListFilterProvider);
  final result = await ref.read(getStudentsUseCaseProvider)(filter);
  return result.fold((f) => throw f, (r) => r);
});

final studentDetailProvider =
    FutureProvider.family<StudentDetail, String>((ref, id) async {
  ref.watch(studentDirectoryProvider);
  ref.watch(progressionStoreProvider);
  final result = await ref.read(getStudentDetailUseCaseProvider)(id);
  return result.fold((f) => throw f, (r) => r);
});

final aiReportProvider =
    FutureProvider.family<AiTeacherReport, String>((ref, id) async {
  final result = await ref.read(getAiReportUseCaseProvider)(id);
  return result.fold((f) => throw f, (r) => r);
});

// ── Mutations (اکشن‌های مدیر) ───────────────────────────────────────────────
class StudentActionsController extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<String?> _run(Future<dynamic> future) async {
    state = const AsyncLoading();
    final result = await future;
    String? error;
    result.fold((f) => error = f.message as String?, (_) {});
    state = const AsyncData(null);
    if (error == null) {
      // لیست و جزئیات را تازه کن
      ref.invalidate(studentsProvider);
    }
    return error;
  }

  Future<String?> suspend(String id, String reason) async {
    final err = await _run(ref.read(updateStatusUseCaseProvider)(
        UpdateStatusParams(
            studentId: id, status: AccountStatus.suspended, reason: reason)));
    ref.invalidate(studentDetailProvider(id));
    return err;
  }

  Future<String?> activate(String id, String reason) async {
    final err = await _run(ref.read(updateStatusUseCaseProvider)(
        UpdateStatusParams(
            studentId: id, status: AccountStatus.active, reason: reason)));
    ref.invalidate(studentDetailProvider(id));
    return err;
  }

  Future<String?> softDelete(String id, String reason) => _run(ref
      .read(softDeleteUseCaseProvider)(
          SoftDeleteParams(studentId: id, reason: reason)));

  Future<String?> sendPasswordReset(String id) =>
      _run(ref.read(sendPasswordResetUseCaseProvider)(id));

  /// ارتقای دستی صنف (اقدام مدیر) — روی سرور واقعی اعمال می‌شود (رفع اشکال:
  /// قبلاً فقط در انبار محلی گوشی شبیه‌سازی می‌شد). خروجی: صنف جدید، یا
  /// null در صورت خطا (پیام خطا در `state` قابل بررسی است).
  Future<int?> promote(String id) async {
    state = const AsyncLoading();
    final result = await ref.read(promoteStudentUseCaseProvider)(id);
    state = const AsyncData(null);
    ref.invalidate(studentDetailProvider(id));
    ref.invalidate(studentsProvider);
    return result.fold((f) => null, (newGrade) => newGrade);
  }

  /// کاهش دستی صنف (اقدام مدیر) — روی سرور واقعی اعمال می‌شود.
  Future<int?> demote(String id) async {
    state = const AsyncLoading();
    final result = await ref.read(demoteStudentUseCaseProvider)(id);
    state = const AsyncData(null);
    ref.invalidate(studentDetailProvider(id));
    ref.invalidate(studentsProvider);
    return result.fold((f) => null, (newGrade) => newGrade);
  }
}

final studentActionsProvider =
    AsyncNotifierProvider<StudentActionsController, void>(
        StudentActionsController.new);
