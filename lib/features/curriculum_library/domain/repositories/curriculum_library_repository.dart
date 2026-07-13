import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/curriculum_book.dart';

abstract class CurriculumLibraryRepository {
  Future<Either<Failure, List<CurriculumBook>>> getBooksForSubject(String subjectId);
  Future<Either<Failure, List<CurriculumBook>>> getAllBooks();
  Future<Either<Failure, CurriculumBook>> addBook({
    required String subjectId,
    required String title,
    required int pageCount,
    required int gradeId,
    required String extractedText,
  });
  Future<Either<Failure, Unit>> deleteBook(String bookId);
}
