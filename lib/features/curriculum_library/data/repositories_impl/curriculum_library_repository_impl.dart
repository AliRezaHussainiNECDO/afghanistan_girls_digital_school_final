import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/curriculum_book.dart';
import '../../domain/repositories/curriculum_library_repository.dart';
import '../datasources/curriculum_library_local_datasource.dart'
    show CurriculumLibraryDataSource;

class CurriculumLibraryRepositoryImpl implements CurriculumLibraryRepository {
  final CurriculumLibraryDataSource dataSource;
  CurriculumLibraryRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<CurriculumBook>>> getBooksForSubject(String subjectId) async {
    try {
      return Right(await dataSource.getBooksForSubject(subjectId));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CurriculumBook>>> getAllBooks() async {
    try {
      return Right(await dataSource.getAllBooks());
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, CurriculumBook>> addBook({
    required String subjectId,
    required String title,
    required int pageCount,
    required int gradeId,
    required String extractedText,
  }) async {
    try {
      return Right(await dataSource.addBook(
        subjectId: subjectId,
        title: title,
        pageCount: pageCount,
        gradeId: gradeId,
        extractedText: extractedText,
      ));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteBook(String bookId) async {
    try {
      await dataSource.deleteBook(bookId);
      return const Right(unit);
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }
}
