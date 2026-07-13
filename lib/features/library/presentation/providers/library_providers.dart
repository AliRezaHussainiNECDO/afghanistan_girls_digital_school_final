import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/library_mock_datasource.dart';
import '../../data/datasources/library_remote_datasource.dart';
import '../../data/repositories_impl/library_repository_impl.dart';
import '../../domain/entities/book.dart';
import '../../domain/repositories/library_repository.dart';
import '../../domain/usecases/search_books_usecase.dart';

/// Mock (فاز ۱) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final libraryDataSourceProvider = Provider<LibraryDataSource>((ref) {
  if (kUseLiveBackend) {
    return LibraryRemoteDataSource(ref.watch(apiClientProvider));
  }
  return LibraryMockDataSource();
});
final libraryRepositoryProvider =
    Provider<LibraryRepository>((ref) => LibraryRepositoryImpl(ref.watch(libraryDataSourceProvider)));
final searchBooksUseCaseProvider =
    Provider((ref) => SearchBooksUseCase(ref.watch(libraryRepositoryProvider)));

final librarySearchQueryProvider = StateProvider<String>((ref) => '');

final booksProvider = FutureProvider<List<Book>>((ref) async {
  final query = ref.watch(librarySearchQueryProvider);
  final result = await ref.read(searchBooksUseCaseProvider).call(query);
  return result.fold((f) => throw f, (v) => v);
});
