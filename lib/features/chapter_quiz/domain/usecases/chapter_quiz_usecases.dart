import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/chapter_quiz_entities.dart';
import '../repositories/chapter_quiz_repository.dart';

class GetChapterQuizUseCase implements UseCase<ChapterQuizForm, String> {
  final ChapterQuizRepository repository;
  GetChapterQuizUseCase(this.repository);
  @override
  Future<Either<Failure, ChapterQuizForm>> call(String chapterId) => repository.getQuiz(chapterId);
}

class SubmitChapterQuizParams extends Equatable {
  final String chapterId;
  final Map<String, int> answers;
  final Map<String, String> textAnswers;
  const SubmitChapterQuizParams({required this.chapterId, required this.answers, this.textAnswers = const {}});
  @override
  List<Object?> get props => [chapterId, answers, textAnswers];
}

class SubmitChapterQuizUseCase implements UseCase<ChapterQuizResult, SubmitChapterQuizParams> {
  final ChapterQuizRepository repository;
  SubmitChapterQuizUseCase(this.repository);
  @override
  Future<Either<Failure, ChapterQuizResult>> call(SubmitChapterQuizParams params) =>
      repository.submit(params.chapterId, params.answers, params.textAnswers);
}
