import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
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
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<ExamQuestion>>> getQuestions(String examId) async {
    try {
      return Right(await dataSource.getQuestions(examId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExamResult>> submitAnswers(String examId, Map<String, int> answers) async {
    try {
      return Right(await dataSource.submitAnswers(examId, answers));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
