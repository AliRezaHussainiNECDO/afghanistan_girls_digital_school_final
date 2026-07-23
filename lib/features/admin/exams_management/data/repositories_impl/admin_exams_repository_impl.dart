import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/admin_exam_entities.dart';
import '../../domain/repositories/admin_exams_repository.dart';
import '../datasources/admin_exams_remote_datasource.dart' show AdminExamsDataSource;

class AdminExamsRepositoryImpl implements AdminExamsRepository {
  final AdminExamsDataSource dataSource;
  AdminExamsRepositoryImpl(this.dataSource);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));

  @override
  Future<Either<Failure, List<AdminExamRow>>> getExams() => _guard(dataSource.getExams);

  @override
  Future<Either<Failure, AdminExamRow>> saveExam(AdminExamRow row) => _guard(() => dataSource.saveExam(row));

  @override
  Future<Either<Failure, Unit>> setExamStatus(String id, ExamAdminStatus status) => _guard(() async {
        await dataSource.setExamStatus(id, status);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> deleteExam(String id) => _guard(() async {
        await dataSource.deleteExam(id);
        return unit;
      });

  @override
  Future<Either<Failure, List<AdminQuestionRow>>> getQuestions(String examId) =>
      _guard(() => dataSource.getQuestions(examId));

  @override
  Future<Either<Failure, AdminQuestionRow>> saveQuestion(AdminQuestionRow row) =>
      _guard(() => dataSource.saveQuestion(row));

  @override
  Future<Either<Failure, Unit>> deleteQuestion(String id) => _guard(() async {
        await dataSource.deleteQuestion(id);
        return unit;
      });

  @override
  Future<Either<Failure, List<AdminQuestionRow>>> generateQuestions(GenerateQuestionsParams params) =>
      _guard(() => dataSource.generateQuestions(params));
}
