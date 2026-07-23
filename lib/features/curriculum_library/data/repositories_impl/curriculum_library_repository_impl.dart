import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
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
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<CurriculumBook>>> getAllBooks() async {
    try {
      return Right(await dataSource.getAllBooks());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
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
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> deleteBook(String bookId) async {
    try {
      await dataSource.deleteBook(bookId);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}
