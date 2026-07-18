import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/student/guardian_link_store.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/parent_mock_datasource.dart';
import '../../data/datasources/parent_remote_datasource.dart';
import '../../data/repositories_impl/parent_repository_impl.dart';
import '../../domain/entities/parent_entities.dart';
import '../../domain/repositories/parent_repository.dart';
import '../../domain/usecases/parent_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final parentDataSourceProvider = Provider<ParentDataSource>((ref) {
  if (kUseLiveBackend) {
    return ParentRemoteDataSource(ref.watch(apiClientProvider));
  }
  return ParentMockDataSource(localeCode: ref.watch(localeProvider).languageCode);
});
final parentRepositoryProvider =
    Provider<ParentRepository>((ref) => ParentRepositoryImpl(ref.watch(parentDataSourceProvider)));

final getLinkedChildrenUseCaseProvider =
    Provider((ref) => GetLinkedChildrenUseCase(ref.watch(parentRepositoryProvider)));
final getChildSummaryUseCaseProvider =
    Provider((ref) => GetChildSummaryUseCase(ref.watch(parentRepositoryProvider)));
final submitInviteCodeUseCaseProvider =
    Provider((ref) => SubmitInviteCodeUseCase(ref.watch(parentRepositoryProvider)));

/// انبار پیوند والد-فرزند به‌صورت Provider — تا هر تغییر (لینک‌شدن فرزند
/// جدید با کد دعوت، تولید کد) خودکار لیست فرزندان و خلاصه‌ها را بازسازی کند.
final guardianLinkStoreProvider =
    ChangeNotifierProvider<GuardianLinkStore>((ref) => GuardianLinkStore.instance);

/// فرزندان تأییدشدهٔ والدِ واردشده (بخش ۱۳ب.۵ — چند فرزند، یک والد).
final linkedChildrenProvider = FutureProvider<List<LinkedChild>>((ref) async {
  ref.watch(guardianLinkStoreProvider); // بازسازی خودکار پس از افزودن فرزند
  final parent = ref.watch(authSessionProvider);
  final result =
      await ref.read(getLinkedChildrenUseCaseProvider).call(parent?.id ?? 'u-parent-demo');
  return result.fold((f) => throw f, (v) => v);
});

/// خلاصهٔ یک فرزند — از منابع واقعی خود شاگرد ساخته می‌شود و با هر تغییر
/// (لینک جدید، پیشرفت مضمون، نتیجهٔ امتحان، ارتقای صنف) خودکار بازسازی
/// می‌شود، چون هر دو انبار ChangeNotifier هستند.
final childSummaryProvider = FutureProvider.family<ChildSummary, String>((ref, studentId) async {
  ref.watch(guardianLinkStoreProvider); // نام/صنف فرزند ممکن است تغییر کند
  ref.watch(progressionStoreProvider); // پیشرفت/ارتقای صنف فرزند
  final result = await ref.read(getChildSummaryUseCaseProvider).call(studentId);
  return result.fold((f) => throw f, (v) => v);
});
