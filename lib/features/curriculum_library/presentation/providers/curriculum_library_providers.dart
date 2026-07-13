import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/curriculum_library_local_datasource.dart';
import '../../data/datasources/curriculum_library_remote_datasource.dart';
import '../../data/repositories_impl/curriculum_library_repository_impl.dart';
import '../../domain/entities/curriculum_book.dart';
import '../../domain/repositories/curriculum_library_repository.dart';
import '../../domain/usecases/curriculum_library_usecases.dart';

/// محلی (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final curriculumLibraryDataSourceProvider =
    Provider<CurriculumLibraryDataSource>((ref) {
  if (kUseLiveBackend) {
    return CurriculumLibraryRemoteDataSource(ref.watch(apiClientProvider));
  }
  return CurriculumLibraryLocalDataSource();
});

final curriculumLibraryRepositoryProvider = Provider<CurriculumLibraryRepository>(
  (ref) => CurriculumLibraryRepositoryImpl(ref.watch(curriculumLibraryDataSourceProvider)),
);

final getBooksForSubjectUseCaseProvider =
    Provider((ref) => GetBooksForSubjectUseCase(ref.watch(curriculumLibraryRepositoryProvider)));
final getAllBooksUseCaseProvider =
    Provider((ref) => GetAllBooksUseCase(ref.watch(curriculumLibraryRepositoryProvider)));
final addBookUseCaseProvider =
    Provider((ref) => AddBookUseCase(ref.watch(curriculumLibraryRepositoryProvider)));
final deleteBookUseCaseProvider =
    Provider((ref) => DeleteBookUseCase(ref.watch(curriculumLibraryRepositoryProvider)));

/// لیست کتاب‌های یک مضمون خاص — هم در پنل مدیریت (آپلود) و هم معلم هوشمند
/// (مصرف‌کننده) استفاده می‌شود.
final booksForSubjectProvider =
    FutureProvider.family<List<CurriculumBook>, String>((ref, subjectId) async {
  final result = await ref.read(getBooksForSubjectUseCaseProvider).call(subjectId);
  return result.fold((f) => throw f, (v) => v);
});

/// نوتیفایر ساده برای رفرش دستی لیست پس از آپلود/حذف (چون Family Provider
/// نیاز به invalidate صریح دارد).
final curriculumLibraryRefreshProvider = StateProvider<int>((ref) => 0);
