import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/chapter_quiz_entities.dart';

abstract class ChapterQuizRepository {
  Future<Either<Failure, ChapterQuizForm>> getQuiz(String chapterId);
  Future<Either<Failure, ChapterQuizResult>> submit(
      String chapterId, Map<String, int> answers, Map<String, String> textAnswers);
}
