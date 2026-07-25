import '../../../exams/domain/entities/exam_entities.dart' show QuestionType;
import '../../domain/entities/chapter_quiz_entities.dart';
import 'chapter_quiz_remote_datasource.dart' show ChapterQuizDataSource;

/// نسخهٔ Mock (فاز ۱ / پیش‌نمایش بدون سرور واقعی) — همیشه یک آزمون ۱۲
/// سؤالی آماده نشان می‌دهد تا جریان UI بدون بک‌اند هم قابل تست باشد.
class ChapterQuizMockDataSource implements ChapterQuizDataSource {
  final Map<String, ChapterQuizResult> _submitted = {};

  @override
  Future<ChapterQuizForm> getQuiz(String chapterId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final result = _submitted[chapterId];
    final questions = List.generate(12, (i) {
      final type = i % 3 == 0
          ? QuestionType.trueFalse
          : i % 3 == 1
              ? QuestionType.mcq
              : QuestionType.essay;
      return ChapterQuizQuestion(
        id: '$chapterId-q${i + 1}',
        text: 'سؤال ${i + 1} از آزمون این فصل',
        qType: type,
        options: type == QuestionType.trueFalse
            ? const ['صحیح', 'غلط']
            : type == QuestionType.mcq
                ? const ['گزینهٔ الف', 'گزینهٔ ب', 'گزینهٔ ج', 'گزینهٔ د']
                : const [],
      );
    });
    if (result == null) {
      return ChapterQuizForm(
        chapterId: chapterId,
        quizId: '$chapterId-quiz',
        title: 'آزمون فصل',
        passThreshold: 40,
        submitted: false,
        questions: questions,
      );
    }
    return ChapterQuizForm(
      chapterId: chapterId,
      quizId: '$chapterId-quiz',
      title: 'آزمون فصل',
      passThreshold: 40,
      submitted: true,
      questions: const [],
      scorePercent: result.scorePercent,
      correctCount: result.correctCount,
      totalCount: result.totalCount,
      passed: result.passed,
      submittedAt: DateTime.now(),
      reviewQuestions: questions
          .map((q) => ChapterQuizReviewQuestion(
                id: q.id,
                text: q.text,
                qType: q.qType,
                options: q.options,
                correctIndex: q.qType == QuestionType.essay ? -1 : 0,
                studentAnswerIndex: q.qType == QuestionType.essay ? -1 : 0,
                isCorrect: q.qType == QuestionType.essay ? null : true,
              ))
          .toList(),
    );
  }

  @override
  Future<ChapterQuizResult> submit(
      String chapterId, Map<String, int> answers, Map<String, String> textAnswers) async {
    await Future.delayed(const Duration(milliseconds: 400));
    const result = ChapterQuizResult(scorePercent: 75, correctCount: 9, totalCount: 12, passed: true);
    _submitted[chapterId] = result;
    return result;
  }
}
