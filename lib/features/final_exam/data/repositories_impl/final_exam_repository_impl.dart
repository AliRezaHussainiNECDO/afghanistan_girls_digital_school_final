import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/final_exam_entities.dart';
import '../../domain/repositories/final_exam_repository.dart';
import '../datasources/final_exam_remote_datasource.dart' show FinalExamDataSource;

class FinalExamRepositoryImpl implements FinalExamRepository {
  final FinalExamDataSource dataSource;
  FinalExamRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, FinalExamAvailability>> getAvailability() async {
    try {
      return Right(await dataSource.getAvailability());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FinalExamQuestion>>> getQuestions(String examId) async {
    try {
      return Right(await dataSource.getQuestions(examId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FinalExamResult>> submit(
      String examId, Map<String, int> answers, Map<String, String> textAnswers) async {
    try {
      return Right(await dataSource.submit(examId, answers, textAnswers));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<FinalExamResultSummary>>> getMyResults({String? studentId}) async {
    try {
      return Right(await dataSource.getMyResults(studentId: studentId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, FinalExamAttemptReview>> getAttemptReview(String attemptId) async {
    try {
      return Right(await dataSource.getAttemptReview(attemptId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}
