import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/book.dart';
import '../repositories/library_repository.dart';

class SearchBooksUseCase implements UseCase<List<Book>, String> {
  final LibraryRepository repository;
  SearchBooksUseCase(this.repository);
  @override
  Future<Either<Failure, List<Book>>> call(String query) => repository.searchBooks(query);
}
