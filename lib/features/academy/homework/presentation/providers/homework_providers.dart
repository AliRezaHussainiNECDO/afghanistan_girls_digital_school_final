import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/network_providers.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/homework_datasource.dart';
import '../../data/datasources/homework_mock_datasource.dart';
import '../../data/datasources/homework_remote_datasource.dart';
import '../../data/repositories_impl/homework_repository_impl.dart';
import '../../domain/entities/homework.dart';
import '../../domain/repositories/homework_repository.dart';
import '../../domain/usecases/homework_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final homeworkDataSourceProvider = Provider<HomeworkDataSource>((ref) {
  if (kUseLiveBackend) {
    return HomeworkRemoteDataSource(ref.watch(apiClientProvider));
  }
  return HomeworkMockDataSource();
});

final homeworkRepositoryProvider = Provider<HomeworkRepository>(
  (ref) => HomeworkRepositoryImpl(ref.watch(homeworkDataSourceProvider)),
);

final getHomeworksUseCaseProvider =
    Provider((ref) => GetHomeworksUseCase(ref.watch(homeworkRepositoryProvider)));
final getHomeworkByIdUseCaseProvider =
    Provider((ref) => GetHomeworkByIdUseCase(ref.watch(homeworkRepositoryProvider)));
final getHomeworkRepliesUseCaseProvider =
    Provider((ref) => GetHomeworkRepliesUseCase(ref.watch(homeworkRepositoryProvider)));
final submitHomeworkPhotoUseCaseProvider =
    Provider((ref) => SubmitHomeworkPhotoUseCase(ref.watch(homeworkRepositoryProvider)));
final sendHomeworkReplyUseCaseProvider =
    Provider((ref) => SendHomeworkReplyUseCase(ref.watch(homeworkRepositoryProvider)));

/// فیلتر فعال تب‌های داشبورد («همه/در انتظار/ارسال‌شده/نمره‌گرفته»).
/// `null` یعنی «همه».
final homeworkStatusFilterProvider = StateProvider<HomeworkStatus?>((ref) => null);

/// فهرست مشق‌های صنف فعلی شاگرد — بر اساس فیلتر فعال بازسازی می‌شود.
final homeworksProvider = FutureProvider.autoDispose<HomeworkListResult>((ref) async {
  final status = ref.watch(homeworkStatusFilterProvider);
  final result = await ref.read(getHomeworksUseCaseProvider).call(GetHomeworksParams(status: status));
  return result.fold((f) => throw f, (v) => v);
});

/// جزئیات یک مشق مشخص (برای صفحهٔ گفت‌وگو).
final homeworkByIdProvider = FutureProvider.autoDispose.family<Homework, String>((ref, id) async {
  final result = await ref.read(getHomeworkByIdUseCaseProvider).call(id);
  return result.fold((f) => throw f, (v) => v);
});

/// تاریخچهٔ گفت‌وگوی «شاگرد ↔ معلم هوشمند» دربارهٔ یک مشق — کلید = homeworkId.
final homeworkRepliesProvider =
    FutureProvider.autoDispose.family<List<HomeworkReply>, String>((ref, homeworkId) async {
  final result = await ref.read(getHomeworkRepliesUseCaseProvider).call(homeworkId);
  return result.fold((f) => throw f, (v) => v);
});

/// نام نمایشی شاگرد فعلی (برای هدر داشبورد).
final currentStudentDisplayNameProvider = Provider<String>((ref) {
  return ref.watch(authSessionProvider)?.fullName ?? '';
});

// ─────────────────────── نمای مدیر: کار خانگیِ یک شاگرد مشخص ─────────────────
// استفاده در `StudentDetailScreen` (بخش «کار خانگی» پروندهٔ شاگرد). جدا از
// `homeworkStatusFilterProvider`/`homeworksProvider` بالا نگه داشته شده تا
// فیلتر/فهرست خودِ شاگرد (وقتی از اپش وارد می‌شود) هرگز با فیلتر/فهرستی که
// مدیر روی پروندهٔ او می‌بیند تداخل نکند.

/// فیلتر فعال تب‌های «کار خانگی» در نمای مدیر — کلید = studentId، پس هر
/// پروندهٔ شاگرد فیلتر خودش را جدا نگه می‌دارد.
final adminHomeworkStatusFilterProvider =
    StateProvider.family<HomeworkStatus?, String>((ref, studentId) => null);

/// فهرست *کامل تاریخچهٔ* کار خانگی‌های یک شاگرد مشخص — برای مدیر (سرور در
/// این حالت فیلتر صنف فعلی را نادیده می‌گیرد، بخش `GET /homework?studentId=`).
final adminStudentHomeworksProvider =
    FutureProvider.autoDispose.family<HomeworkListResult, String>((ref, studentId) async {
  final status = ref.watch(adminHomeworkStatusFilterProvider(studentId));
  final result = await ref
      .read(getHomeworksUseCaseProvider)
      .call(GetHomeworksParams(status: status, studentId: studentId));
  return result.fold((f) => throw f, (v) => v);
});
