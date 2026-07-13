import '../../../../core/network/api_client.dart';
import '../../domain/entities/exam_entities.dart';

/// قرارداد مشترک DataSource امتحانات — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class ExamsDataSource {
  Future<List<ExamSummary>> getAvailableExams();
  Future<List<ExamQuestion>> getQuestions(String examId);
  Future<ExamResult> submitAnswers(String examId, Map<String, int> answers);
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
              options: (q['options'] as List? ?? []).map((o) => o.toString()).toList(),
              correctIndex: -1, // مخفی — نمره‌دهی سمت سرور
            ))
        .toList();
  }

  @override
  Future<ExamResult> submitAnswers(String examId, Map<String, int> answers) async {
    final data = await _api.post('/exams/$examId/submit', data: {'answers': answers});
    return ExamResult(
      scorePercent: (data['scorePercent'] as num?)?.toDouble() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
    );
  }

  ExamType _typeFrom(String? s) => ExamType.values.firstWhere(
        (t) => t.name == s,
        orElse: () => ExamType.dailyQuiz,
      );
}
