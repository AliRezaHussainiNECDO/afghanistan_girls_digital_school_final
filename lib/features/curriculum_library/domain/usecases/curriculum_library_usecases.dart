import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/curriculum_book.dart';
import '../repositories/curriculum_library_repository.dart';

class GetBooksForSubjectUseCase implements UseCase<List<CurriculumBook>, String> {
  final CurriculumLibraryRepository repository;
  GetBooksForSubjectUseCase(this.repository);
  @override
  Future<Either<Failure, List<CurriculumBook>>> call(String subjectId) =>
      repository.getBooksForSubject(subjectId);
}

class GetAllBooksUseCase implements UseCase<List<CurriculumBook>, NoParams> {
  final CurriculumLibraryRepository repository;
  GetAllBooksUseCase(this.repository);
  @override
  Future<Either<Failure, List<CurriculumBook>>> call(NoParams params) =>
      repository.getAllBooks();
}

class AddBookParams extends Equatable {
  final String subjectId;
  final String title;
  final int pageCount;
  final int gradeId;
  final String extractedText;
  const AddBookParams({
    required this.subjectId,
    required this.title,
    required this.pageCount,
    required this.gradeId,
    required this.extractedText,
  });
  @override
  List<Object?> get props => [subjectId, title, pageCount, gradeId, extractedText.length];
}

class AddBookUseCase implements UseCase<CurriculumBook, AddBookParams> {
  final CurriculumLibraryRepository repository;
  AddBookUseCase(this.repository);
  @override
  Future<Either<Failure, CurriculumBook>> call(AddBookParams params) => repository.addBook(
        subjectId: params.subjectId,
        title: params.title,
        pageCount: params.pageCount,
        gradeId: params.gradeId,
        extractedText: params.extractedText,
      );
}

class DeleteBookUseCase implements UseCase<Unit, String> {
  final CurriculumLibraryRepository repository;
  DeleteBookUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String bookId) => repository.deleteBook(bookId);
}
