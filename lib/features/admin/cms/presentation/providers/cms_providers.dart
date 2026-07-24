import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/cms_mock_datasource.dart';
import '../../data/datasources/cms_remote_datasource.dart';
import '../../data/repositories_impl/cms_repository_impl.dart';
import '../../domain/entities/cms_entities.dart';
import '../../domain/repositories/cms_repository.dart';
import '../../domain/usecases/cms_usecases.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final cmsDataSourceProvider = Provider<CmsDataSource>((ref) {
  if (kUseLiveBackend) {
    return CmsRemoteDataSource(ref.watch(apiClientProvider));
  }
  return CmsMockDataSource();
});
final cmsRepositoryProvider = Provider<CmsRepository>((ref) => CmsRepositoryImpl(ref.watch(cmsDataSourceProvider)));

// ── UseCase providers ──
final getBooksUseCaseProvider = Provider((ref) => GetBooksUseCase(ref.watch(cmsRepositoryProvider)));
final saveBookUseCaseProvider = Provider((ref) => SaveBookUseCase(ref.watch(cmsRepositoryProvider)));
final deleteBookUseCaseProvider = Provider((ref) => DeleteBookUseCase(ref.watch(cmsRepositoryProvider)));
final setBookStatusUseCaseProvider = Provider((ref) => SetBookStatusUseCase(ref.watch(cmsRepositoryProvider)));

final getLessonsUseCaseProvider = Provider((ref) => GetLessonsUseCase(ref.watch(cmsRepositoryProvider)));
final saveLessonUseCaseProvider = Provider((ref) => SaveLessonUseCase(ref.watch(cmsRepositoryProvider)));
final deleteLessonUseCaseProvider = Provider((ref) => DeleteLessonUseCase(ref.watch(cmsRepositoryProvider)));
final setLessonStatusUseCaseProvider = Provider((ref) => SetLessonStatusUseCase(ref.watch(cmsRepositoryProvider)));

final getQuestionsUseCaseProvider = Provider((ref) => GetQuestionsUseCase(ref.watch(cmsRepositoryProvider)));
final saveQuestionUseCaseProvider = Provider((ref) => SaveQuestionUseCase(ref.watch(cmsRepositoryProvider)));
final deleteQuestionUseCaseProvider = Provider((ref) => DeleteQuestionUseCase(ref.watch(cmsRepositoryProvider)));
final setQuestionStatusUseCaseProvider =
    Provider((ref) => SetQuestionStatusUseCase(ref.watch(cmsRepositoryProvider)));

final getInviteCodesUseCaseProvider =
    Provider((ref) => GetInviteCodesUseCase(ref.watch(cmsRepositoryProvider)));
final generateInviteCodesUseCaseProvider =
    Provider((ref) => GenerateInviteCodesUseCase(ref.watch(cmsRepositoryProvider)));
final revokeInviteCodeUseCaseProvider =
    Provider((ref) => RevokeInviteCodeUseCase(ref.watch(cmsRepositoryProvider)));

// ── List providers (خوانده‌شده و قابل invalidate پس از هر تغییر) ──
final cmsBooksProvider = FutureProvider<List<CmsBookRow>>((ref) async {
  final result = await ref.read(getBooksUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final cmsLessonsProvider = FutureProvider<List<CmsLessonRow>>((ref) async {
  final result = await ref.read(getLessonsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

final cmsQuestionsProvider = FutureProvider<List<CmsQuestionRow>>((ref) async {
  final result = await ref.read(getQuestionsUseCaseProvider).call(const NoParams());
  return result.fold((f) => throw f, (v) => v);
});

/// کدهای دعوت — `type`: 'student' یا 'instructor'.
///
/// رفع اشکال (۲۴ جولای): قبلاً این Provider دو `ChangeNotifierProvider`
/// سراسری (`studentInviteStoreProvider`/`instructorInviteStoreProvider`،
/// پوشش‌دهندهٔ Storeهای اکنون‌حذف‌شدهٔ `core/`) را فقط برای بازسازیِ زندهٔ
/// حالت Mock `watch` می‌کرد؛ هر دو صفحهٔ فراخوان (`cms_screen.dart`،
/// `instructor_codes_tab.dart`) از قبل بعد از هر ساخت/ابطال به‌صراحت
/// `ref.invalidate(cmsInviteCodesProvider(type))` را صدا می‌زنند، پس آن دو
/// Watch عملاً افزونه بودند — حذف شدند.
final cmsInviteCodesProvider =
    FutureProvider.family<List<CmsInviteCodeRow>, String>((ref, type) async {
  final result = await ref.read(getInviteCodesUseCaseProvider).call(type);
  return result.fold((f) => throw f, (v) => v);
});
