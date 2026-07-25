import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/final_exam_entities.dart';

abstract class FinalExamRepository {
  Future<Either<Failure, FinalExamAvailability>> getAvailability();
  Future<Either<Failure, List<FinalExamQuestion>>> getQuestions(String examId);
  Future<Either<Failure, FinalExamResult>> submit(
      String examId, Map<String, int> answers, Map<String, String> textAnswers);
  Future<Either<Failure, List<FinalExamResultSummary>>> getMyResults({String? studentId});
  Future<Either<Failure, FinalExamAttemptReview>> getAttemptReview(String attemptId);
}
