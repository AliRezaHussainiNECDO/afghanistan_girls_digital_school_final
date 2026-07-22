import '../../../../core/network/api_client.dart';
import '../../domain/entities/exam_entities.dart';

/// قرارداد مشترک DataSource امتحانات — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class ExamsDataSource {
  Future<List<ExamSummary>> getAvailableExams();
  Future<List<ExamQuestion>> getQuestions(String examId);

  /// [answers]: سؤالات بسته (گزینهٔ انتخابی)؛ [textAnswers]: پاسخ متنی
  /// سؤالات تشریحی (نمره‌دهی AI سمت سرور — migration 0030).
  Future<ExamResult> submitAnswers(String examId, Map<String, int> answers, Map<String, String> textAnswers);

  /// نتایج امتحانات رسمیِ شاگرد (بعد از دادن هر امتحان) — بدون [studentId]
  /// برای خودِ کاربر واردشده؛ با [studentId] برای والدِ لینک‌شده/مدیر که
  /// می‌خواهد نتایج یک شاگرد مشخص را ببیند (همان دادهٔ داشبورد شاگرد).
  Future<List<ExamResultSummary>> getMyResults({String? studentId});

  /// مرور سؤال‌به‌سؤالِ یک تلاش مشخص — پاسخ شاگرد + درست/غلط.
  Future<ExamAttemptReview> getAttemptReview(String attemptId);
}

/// پیاده‌سازی واقعی — روتر exams زیر `/api/v1` (بخش ۷/۸ سند).
///
/// نکتهٔ امنیتی: پاسخ صحیح هرگز از سرور دریافت نمی‌شود (`correctIndex = -1`)؛
/// نمره‌دهی ۱۰۰٪ سمت سرور در `submitAnswers` انجام می‌شود (بخش ۷.۲/۴.۱).
class ExamsRemoteDataSource implements ExamsDataSource {
  final ApiClient _api;
  ExamsRemoteDataSource(this._api);

  @override
  Future<List<ExamSummary>> getAvailableExams() async {
    final data = await _api.get('/exams/available');
    final list = (data['exams'] as List? ?? []);
    return list
        .map((e) => ExamSummary(
              id: e['id'] as String,
              subjectNameFa: e['subjectNameFa'] as String? ?? '',
              type: _typeFrom(e['type'] as String?),
              durationMinutes: (e['durationMinutes'] as num?)?.toInt() ?? 10,
              questionCount: (e['questionCount'] as num?)?.toInt() ?? 0,
              gradeNumber: (e['gradeNumber'] as num?)?.toInt() ?? 0,
              bestScorePercent: (e['bestScorePercent'] as num?)?.toDouble(),
              passed: e['passed'] as bool? ?? false,
            ))
        .toList();
  }

  @override
  Future<List<ExamQuestion>> getQuestions(String examId) async {
    final data = await _api.get('/exams/$examId/questions');
    final list = (data['questions'] as List? ?? []);
    return list
        .map((q) => ExamQuestion(
              id: q['id'] as String,
              text: q['text'] as String? ?? '',
              qType: QuestionTypeX.fromKey(q['qType'] as String?),
              options: (q['options'] as List? ?? []).map((o) => o.toString()).toList(),
              correctIndex: -1, // مخفی — نمره‌دهی سمت سرور
            ))
        .toList();
  }

  @override
  Future<ExamResult> submitAnswers(String examId, Map<String, int> answers, Map<String, String> textAnswers) async {
    final data = await _api.post('/exams/$examId/submit', data: {
      'answers': answers,
      if (textAnswers.isNotEmpty) 'textAnswers': textAnswers,
    });
    return ExamResult(
      scorePercent: (data['scorePercent'] as num?)?.toDouble() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      promoted: data['promoted'] as bool? ?? false,
      newGrade: (data['newGrade'] as num?)?.toInt(),
      attemptId: data['attemptId'] as String?,
      passed: data['passed'] as bool? ?? false,
    );
  }

  @override
  Future<List<ExamResultSummary>> getMyResults({String? studentId}) async {
    final data = await _api.get(
      '/exams/my-results',
      queryParameters: studentId != null ? {'studentId': studentId} : null,
    );
    final list = (data['results'] as List? ?? []);
    return list
        .map((r) => ExamResultSummary(
              attemptId: r['attemptId'] as String,
              examId: r['examId'] as String,
              examTitle: r['examTitle'] as String? ?? '',
              subjectNameFa: r['subjectNameFa'] as String? ?? '',
              gradeNumber: (r['gradeNumber'] as num?)?.toInt() ?? 0,
              type: _typeFrom(r['type'] as String?),
              scorePercent: (r['scorePercent'] as num?)?.toDouble() ?? 0,
              correctCount: (r['correctCount'] as num?)?.toInt() ?? 0,
              totalCount: (r['totalCount'] as num?)?.toInt() ?? 0,
              passed: r['passed'] as bool? ?? false,
              submittedAt: DateTime.tryParse((r['submittedAt'] as String?) ?? '') ?? DateTime.now(),
            ))
        .toList();
  }

  @override
  Future<ExamAttemptReview> getAttemptReview(String attemptId) async {
    final data = await _api.get('/exams/attempts/$attemptId');
    final questions = (data['questions'] as List? ?? [])
        .map((q) => ExamReviewQuestion(
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
        .toList();
    return ExamAttemptReview(
      attemptId: data['attemptId'] as String,
      examId: data['examId'] as String,
      examTitle: data['examTitle'] as String? ?? '',
      subjectNameFa: data['subjectNameFa'] as String? ?? '',
      gradeNumber: (data['gradeNumber'] as num?)?.toInt() ?? 0,
      type: _typeFrom(data['type'] as String?),
      scorePercent: (data['scorePercent'] as num?)?.toDouble() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      submittedAt: DateTime.tryParse((data['submittedAt'] as String?) ?? '') ?? DateTime.now(),
      questions: questions,
      passed: data['passed'] as bool? ?? false,
    );
  }

  ExamType _typeFrom(String? s) => ExamType.values.firstWhere(
        (t) => t.name == s,
        orElse: () => ExamType.dailyQuiz,
      );
}
