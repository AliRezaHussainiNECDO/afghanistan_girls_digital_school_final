import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/final_exam_entities.dart';
import '../../domain/repositories/admin_final_exam_repository.dart';
import '../datasources/admin_final_exam_remote_datasource.dart' show AdminFinalExamDataSource;

class AdminFinalExamRepositoryImpl implements AdminFinalExamRepository {
  final AdminFinalExamDataSource dataSource;
  AdminFinalExamRepositoryImpl(this.dataSource);

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
  Future<Either<Failure, List<AdminFinalExamRow>>> getFinalExams({int? gradeNumber}) =>
      _guard(() => dataSource.getFinalExams(gradeNumber: gradeNumber));

  @override
  Future<Either<Failure, AdminFinalExamRow>> createFinalExam({required int gradeNumber, required String academicYear, required String title}) =>
      _guard(() => dataSource.createFinalExam(gradeNumber: gradeNumber, academicYear: academicYear, title: title));

  @override
  Future<Either<Failure, Unit>> setStatus(String id, FinalExamAdminStatus status) => _guard(() async {
        await dataSource.setStatus(id, status);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> deleteFinalExam(String id) => _guard(() async {
        await dataSource.deleteFinalExam(id);
        return unit;
      });

  @override
  Future<Either<Failure, List<AdminFinalExamQuestionRow>>> getQuestions(String finalExamId) =>
      _guard(() => dataSource.getQuestions(finalExamId));

  @override
  Future<Either<Failure, AdminFinalExamQuestionRow>> saveQuestion(AdminFinalExamQuestionRow row) =>
      _guard(() => dataSource.saveQuestion(row));

  @override
  Future<Either<Failure, Unit>> deleteQuestion(String id) => _guard(() async {
        await dataSource.deleteQuestion(id);
        return unit;
      });

  @override
  Future<Either<Failure, GenerateFinalExamResult>> generateQuestions(String finalExamId, {int perSubjectCount = 3}) =>
      _guard(() => dataSource.generateQuestions(finalExamId, perSubjectCount: perSubjectCount));
}
