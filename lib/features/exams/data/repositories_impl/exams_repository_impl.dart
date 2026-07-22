import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/exam_entities.dart';
import '../../domain/repositories/exams_repository.dart';
import '../datasources/exams_remote_datasource.dart' show ExamsDataSource;

class ExamsRepositoryImpl implements ExamsRepository {
  final ExamsDataSource dataSource;
  ExamsRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<ExamSummary>>> getAvailableExams() async {
    try {
      return Right(await dataSource.getAvailableExams());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ExamQuestion>>> getQuestions(String examId) async {
    try {
      return Right(await dataSource.getQuestions(examId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExamResult>> submitAnswers(
      String examId, Map<String, int> answers, Map<String, String> textAnswers) async {
    try {
      return Right(await dataSource.submitAnswers(examId, answers, textAnswers));
    } on ApiException catch (e) {
      // مهم برای این متد به‌خصوص: پیام واضح «قبلاً داده‌اید» (۴۰۹) باید دقیقاً
      // همان پیام دری/محلی‌شدهٔ سرور به شاگرد نشان داده شود، نه یک خطای فنی خام.
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ExamResultSummary>>> getMyResults({String? studentId}) async {
    try {
      return Right(await dataSource.getMyResults(studentId: studentId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExamAttemptReview>> getAttemptReview(String attemptId) async {
    try {
      return Right(await dataSource.getAttemptReview(attemptId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// همان الگوی بقیهٔ Repositoryهای برنامه (مثلاً seminars) — پیام تمیز و
  /// محلی‌شدهٔ سرور را نگه می‌دارد، نه `Exception.toString()` خام.
  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest
          ? ValidationFailure(e.message)
          : ServerFailure(e.message, code: e.code));
}
