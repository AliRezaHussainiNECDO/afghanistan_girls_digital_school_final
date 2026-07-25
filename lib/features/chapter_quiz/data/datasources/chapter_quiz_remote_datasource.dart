import '../../../../core/network/api_client.dart';
import '../../../exams/domain/entities/exam_entities.dart' show QuestionTypeX;
import '../../domain/entities/chapter_quiz_entities.dart';

abstract class ChapterQuizDataSource {
  /// فورم آزمون فصل — قبل یا بعد از ارسال (بسته به اینکه شاگرد قبلاً داده یا نه).
  Future<ChapterQuizForm> getQuiz(String chapterId);

  /// ارسال پاسخ‌ها — یک‌بار مجاز (سرور تلاش دوباره را رد می‌کند).
  Future<ChapterQuizResult> submit(String chapterId, Map<String, int> answers, Map<String, String> textAnswers);
}

/// پیاده‌سازی واقعی — `backend/src/routes/chapterQuizzes.ts`.
class ChapterQuizRemoteDataSource implements ChapterQuizDataSource {
  final ApiClient _api;
  ChapterQuizRemoteDataSource(this._api);

  @override
  Future<ChapterQuizForm> getQuiz(String chapterId) async {
    try {
      final data = await _api.get('/chapters/$chapterId/quiz');
      return _formFrom(chapterId, data);
    } on ApiException catch (e) {
      // QUIZ_NOT_READY (404) — حالت طبیعی، نه خطا: هنوز آزمونی ساخته نشده.
      if (e.code == 'QUIZ_NOT_READY') return ChapterQuizForm.notReady;
      rethrow;
    }
  }

  @override
  Future<ChapterQuizResult> submit(
      String chapterId, Map<String, int> answers, Map<String, String> textAnswers) async {
    final data = await _api.post('/chapters/$chapterId/quiz/submit', data: {
      'answers': answers,
      if (textAnswers.isNotEmpty) 'textAnswers': textAnswers,
    });
    return ChapterQuizResult(
      scorePercent: (data['scorePercent'] as num?)?.toDouble() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      passed: data['passed'] as bool? ?? false,
    );
  }

  ChapterQuizForm _formFrom(String chapterId, Map<String, dynamic> data) {
    final submitted = data['submitted'] as bool? ?? false;
    final questions = (data['questions'] as List? ?? []);
    if (!submitted) {
      return ChapterQuizForm(
        chapterId: chapterId,
        quizId: data['quizId'] as String? ?? '',
        title: data['title'] as String? ?? '',
        passThreshold: (data['passThreshold'] as num?)?.toDouble() ?? 40,
        submitted: false,
        questions: questions
            .map((q) => ChapterQuizQuestion(
                  id: q['id'] as String,
                  text: q['text'] as String? ?? '',
                  qType: QuestionTypeX.fromKey(q['qType'] as String?),
                  options: (q['options'] as List? ?? []).map((o) => o.toString()).toList(),
                ))
            .toList(),
      );
    }
    return ChapterQuizForm(
      chapterId: chapterId,
      quizId: data['quizId'] as String? ?? '',
      title: data['title'] as String? ?? '',
      passThreshold: (data['passThreshold'] as num?)?.toDouble() ?? 40,
      submitted: true,
      questions: const [],
      scorePercent: (data['scorePercent'] as num?)?.toDouble() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      passed: data['passed'] as bool? ?? false,
      submittedAt: DateTime.tryParse((data['submittedAt'] as String?) ?? '') ?? DateTime.now(),
      reviewQuestions: questions
          .map((q) => ChapterQuizReviewQuestion(
                id: q['id'] as String,
                text: q['text'] as String? ?? '',
                qType: QuestionTypeX.fromKey(q['qType'] as String?),
                options: (q['options'] as List? ?? []).map((o) => o.toString()).toList(),
                correctIndex: (q['correctIndex'] as num?)?.toInt() ?? -1,
                studentAnswerIndex: (q['studentAnswerIndex'] as num?)?.toInt() ?? -1,
                studentAnswerText: q['studentAnswerText'] as String? ?? '',
                modelAnswerText: q['modelAnswerText'] as String? ?? '',
                isCorrect: q['isCorrect'] as bool?,
                essayScore: (q['essayScore'] as num?)?.toDouble(),
                essayFeedback: q['essayFeedback'] as String? ?? '',
              ))
          .toList(),
    );
  }
}
