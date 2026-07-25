import '../../../../core/network/api_client.dart';
import '../../domain/entities/final_exam_entities.dart';

abstract class FinalExamDataSource {
  Future<FinalExamAvailability> getAvailability();
  Future<List<FinalExamQuestion>> getQuestions(String examId);
  Future<FinalExamResult> submit(String examId, Map<String, int> answers, Map<String, String> textAnswers);
  Future<List<FinalExamResultSummary>> getMyResults({String? studentId});
  Future<FinalExamAttemptReview> getAttemptReview(String attemptId);
}

/// پیاده‌سازی واقعی — `backend/src/routes/finalExams.ts`.
class FinalExamRemoteDataSource implements FinalExamDataSource {
  final ApiClient _api;
  FinalExamRemoteDataSource(this._api);

  @override
  Future<FinalExamAvailability> getAvailability() async {
    final data = await _api.get('/final-exam/available');
    final examJson = data['exam'];
    return FinalExamAvailability(
      exam: examJson == null
          ? null
          : FinalExamInfo(
              id: examJson['id'] as String,
              title: examJson['title'] as String? ?? '',
              gradeNumber: (examJson['gradeNumber'] as num?)?.toInt() ?? 0,
              questionCount: (examJson['questionCount'] as num?)?.toInt() ?? 0,
              passThreshold: (examJson['passThreshold'] as num?)?.toDouble() ?? 80,
            ),
      eligible: data['eligible'] as bool? ?? false,
      nextAttemptNumber: (data['nextAttemptNumber'] as num?)?.toInt() ?? 1,
      reason: data['reason'] as String?,
      retakeAvailableAt:
          data['retakeAvailableAt'] != null ? DateTime.tryParse(data['retakeAvailableAt'] as String) : null,
      bestScorePercent: (data['bestScorePercent'] as num?)?.toDouble(),
    );
  }

  @override
  Future<List<FinalExamQuestion>> getQuestions(String examId) async {
    final data = await _api.get('/final-exams/$examId/questions');
    final list = (data['questions'] as List? ?? []);
    return list
        .map((q) => FinalExamQuestion(
              id: q['id'] as String,
              text: q['text'] as String? ?? '',
              qType: QuestionTypeX.fromKey(q['qType'] as String?),
              options: (q['options'] as List? ?? []).map((o) => o.toString()).toList(),
              subjectId: q['subjectId'] as String? ?? '',
              subjectNameFa: q['subjectNameFa'] as String? ?? '',
            ))
        .toList();
  }

  @override
  Future<FinalExamResult> submit(String examId, Map<String, int> answers, Map<String, String> textAnswers) async {
    final data = await _api.post('/final-exams/$examId/submit', data: {
      'answers': answers,
      if (textAnswers.isNotEmpty) 'textAnswers': textAnswers,
    });
    return FinalExamResult(
      attemptId: data['attemptId'] as String? ?? '',
      scorePercent: (data['scorePercent'] as num?)?.toDouble() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      passed: data['passed'] as bool? ?? false,
      promoted: data['promoted'] as bool? ?? false,
      newGrade: (data['newGrade'] as num?)?.toInt(),
    );
  }

  @override
  Future<List<FinalExamResultSummary>> getMyResults({String? studentId}) async {
    final data = await _api.get('/final-exam/my-results',
        queryParameters: studentId != null ? {'studentId': studentId} : null);
    final list = (data['results'] as List? ?? []);
    return list
        .map((r) => FinalExamResultSummary(
              attemptId: r['attemptId'] as String,
              examId: r['examId'] as String,
              examTitle: r['examTitle'] as String? ?? '',
              gradeNumber: (r['gradeNumber'] as num?)?.toInt() ?? 0,
              attemptNumber: (r['attemptNumber'] as num?)?.toInt() ?? 1,
              scorePercent: (r['scorePercent'] as num?)?.toDouble() ?? 0,
              correctCount: (r['correctCount'] as num?)?.toInt() ?? 0,
              totalCount: (r['totalCount'] as num?)?.toInt() ?? 0,
              passed: r['passed'] as bool? ?? false,
              submittedAt: DateTime.tryParse((r['submittedAt'] as String?) ?? '') ?? DateTime.now(),
              retakeAvailableAt:
                  r['retakeAvailableAt'] != null ? DateTime.tryParse(r['retakeAvailableAt'] as String) : null,
            ))
        .toList();
  }

  @override
  Future<FinalExamAttemptReview> getAttemptReview(String attemptId) async {
    final data = await _api.get('/final-exam/attempts/$attemptId');
    final questions = (data['questions'] as List? ?? [])
        .map((q) => FinalExamReviewQuestion(
              id: q['id'] as String,
              text: q['text'] as String? ?? '',
              qType: QuestionTypeX.fromKey(q['qType'] as String?),
              subjectNameFa: q['subjectNameFa'] as String? ?? '',
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
    return FinalExamAttemptReview(
      attemptId: data['attemptId'] as String,
      examTitle: data['examTitle'] as String? ?? '',
      gradeNumber: (data['gradeNumber'] as num?)?.toInt() ?? 0,
      attemptNumber: (data['attemptNumber'] as num?)?.toInt() ?? 1,
      scorePercent: (data['scorePercent'] as num?)?.toDouble() ?? 0,
      correctCount: (data['correctCount'] as num?)?.toInt() ?? 0,
      totalCount: (data['totalCount'] as num?)?.toInt() ?? 0,
      passed: data['passed'] as bool? ?? false,
      submittedAt: DateTime.tryParse((data['submittedAt'] as String?) ?? '') ?? DateTime.now(),
      questions: questions,
    );
  }
}
