import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import 'package:equatable/equatable.dart';
import '../entities/exam_entities.dart';
import '../repositories/exams_repository.dart';

class GetAvailableExamsUseCase implements UseCase<List<ExamSummary>, NoParams> {
  final ExamsRepository repository;
  GetAvailableExamsUseCase(this.repository);
  @override
  Future<Either<Failure, List<ExamSummary>>> call(NoParams params) => repository.getAvailableExams();
}

class GetQuestionsUseCase implements UseCase<List<ExamQuestion>, String> {
  final ExamsRepository repository;
  GetQuestionsUseCase(this.repository);
  @override
  Future<Either<Failure, List<ExamQuestion>>> call(String examId) => repository.getQuestions(examId);
}

class SubmitAnswersParams extends Equatable {
  final String examId;
  final Map<String, int> answers;

  /// پاسخ متنی سؤالات تشریحی — questionId → متن (migration 0030).
  final Map<String, String> textAnswers;
  const SubmitAnswersParams({required this.examId, required this.answers, this.textAnswers = const {}});
  @override
  List<Object?> get props => [examId, answers, textAnswers];
}

class SubmitAnswersUseCase implements UseCase<ExamResult, SubmitAnswersParams> {
  final ExamsRepository repository;
  SubmitAnswersUseCase(this.repository);
  @override
  Future<Either<Failure, ExamResult>> call(SubmitAnswersParams params) =>
      repository.submitAnswers(params.examId, params.answers, params.textAnswers);
}
