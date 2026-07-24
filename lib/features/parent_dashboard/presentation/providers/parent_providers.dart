import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/localization/locale_provider.dart';
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

/// فرزندان تأییدشدهٔ والدِ واردشده (بخش ۱۳ب.۵ — چند فرزند، یک والد).
///
/// رفع اشکال (۲۴ جولای): قبلاً این Provider یک `ChangeNotifierProvider`
/// سراسری (`guardianLinkStoreProvider`، پوششِ Store اکنون‌حذف‌شدهٔ
/// `core/student/guardian_link_store.dart`) را فقط برای بازسازیِ زندهٔ
/// حالت Mock `watch` می‌کرد. تنها محل واقعیِ افزودن فرزند
/// (`_AwaitingLinkView.onSubmitted` در `parent_dashboard_screen.dart`) از
/// قبل به‌صراحت `ref.invalidate(linkedChildrenProvider)` را صدا می‌زند، پس
/// آن Watch افزونه بود — حذف شد.
final linkedChildrenProvider = FutureProvider<List<LinkedChild>>((ref) async {
  final parent = ref.watch(authSessionProvider);
  final result =
      await ref.read(getLinkedChildrenUseCaseProvider).call(parent?.id ?? 'u-parent-demo');
  return result.fold((f) => throw f, (v) => v);
});

/// خلاصهٔ یک فرزند — از منابع واقعی خود شاگرد ساخته می‌شود.
final childSummaryProvider = FutureProvider.family<ChildSummary, String>((ref, studentId) async {
  ref.watch(progressionStoreProvider); // پیشرفت/ارتقای صنف فرزند
  final result = await ref.read(getChildSummaryUseCaseProvider).call(studentId);
  return result.fold((f) => throw f, (v) => v);
});
