import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/final_exam_entities.dart';
import '../repositories/final_exam_repository.dart';

class GetFinalExamAvailabilityUseCase implements UseCase<FinalExamAvailability, NoParams> {
  final FinalExamRepository repository;
  GetFinalExamAvailabilityUseCase(this.repository);
  @override
  Future<Either<Failure, FinalExamAvailability>> call(NoParams params) => repository.getAvailability();
}

class GetFinalExamQuestionsUseCase implements UseCase<List<FinalExamQuestion>, String> {
  final FinalExamRepository repository;
  GetFinalExamQuestionsUseCase(this.repository);
  @override
  Future<Either<Failure, List<FinalExamQuestion>>> call(String examId) => repository.getQuestions(examId);
}

class SubmitFinalExamParams extends Equatable {
  final String examId;
  final Map<String, int> answers;
  final Map<String, String> textAnswers;
  const SubmitFinalExamParams({required this.examId, required this.answers, this.textAnswers = const {}});
  @override
  List<Object?> get props => [examId, answers, textAnswers];
}

class SubmitFinalExamUseCase implements UseCase<FinalExamResult, SubmitFinalExamParams> {
  final FinalExamRepository repository;
  SubmitFinalExamUseCase(this.repository);
  @override
  Future<Either<Failure, FinalExamResult>> call(SubmitFinalExamParams params) =>
      repository.submit(params.examId, params.answers, params.textAnswers);
}

class GetMyFinalExamResultsUseCase implements UseCase<List<FinalExamResultSummary>, String?> {
  final FinalExamRepository repository;
  GetMyFinalExamResultsUseCase(this.repository);
  @override
  Future<Either<Failure, List<FinalExamResultSummary>>> call(String? studentId) =>
      repository.getMyResults(studentId: studentId);
}

class GetFinalExamAttemptReviewUseCase implements UseCase<FinalExamAttemptReview, String> {
  final FinalExamRepository repository;
  GetFinalExamAttemptReviewUseCase(this.repository);
  @override
  Future<Either<Failure, FinalExamAttemptReview>> call(String attemptId) => repository.getAttemptReview(attemptId);
}
