import '../../domain/entities/final_exam_entities.dart';
import 'final_exam_remote_datasource.dart' show FinalExamDataSource;

/// نسخهٔ Mock — یک امتحان فاینل ۹ سؤالی (۳ مضمون × ۳ سؤال) برای پیش‌نمایش
/// بدون سرور واقعی.
class FinalExamMockDataSource implements FinalExamDataSource {
  static const _subjects = ['ریاضی', 'فزیک', 'ادبیات دری'];
  FinalExamResult? _lastResult;

  @override
  Future<FinalExamAvailability> getAvailability() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return FinalExamAvailability(
      exam: const FinalExamInfo(id: 'fe1', title: 'امتحان فاینل صنف هفتم', gradeNumber: 7, questionCount: 9, passThreshold: 80),
      eligible: _lastResult == null || !(_lastResult!.passed),
      nextAttemptNumber: 1,
      bestScorePercent: _lastResult?.scorePercent,
    );
  }

  @override
  Future<List<FinalExamQuestion>> getQuestions(String examId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      for (final s in _subjects)
        for (var i = 0; i < 3; i++)
          FinalExamQuestion(
            id: '$examId-$s-$i',
            text: 'سؤال ${i + 1} از $s',
            qType: i == 0 ? QuestionType.trueFalse : (i == 1 ? QuestionType.mcq : QuestionType.essay),
            options: i == 0
                ? const ['صحیح', 'غلط']
                : i == 1
                    ? const ['الف', 'ب', 'ج', 'د']
                    : const [],
            subjectId: s,
            subjectNameFa: s,
          ),
    ];
  }

  @override
  Future<FinalExamResult> submit(String examId, Map<String, int> answers, Map<String, String> textAnswers) async {
    await Future.delayed(const Duration(milliseconds: 500));
    const result = FinalExamResult(attemptId: 'a1', scorePercent: 85, correctCount: 8, totalCount: 9, passed: true, promoted: true, newGrade: 8);
    _lastResult = result;
    return result;
  }

  @override
  Future<List<FinalExamResultSummary>> getMyResults({String? studentId}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (_lastResult == null) return [];
    return [
      FinalExamResultSummary(
        attemptId: _lastResult!.attemptId,
        examId: 'fe1',
        examTitle: 'امتحان فاینل صنف هفتم',
        gradeNumber: 7,
        attemptNumber: 1,
        scorePercent: _lastResult!.scorePercent,
        correctCount: _lastResult!.correctCount,
        totalCount: _lastResult!.totalCount,
        passed: _lastResult!.passed,
        submittedAt: DateTime.now(),
      ),
    ];
  }

  @override
  Future<FinalExamAttemptReview> getAttemptReview(String attemptId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final questions = await getQuestions('fe1');
    return FinalExamAttemptReview(
      attemptId: attemptId,
      examTitle: 'امتحان فاینل صنف هفتم',
      gradeNumber: 7,
      attemptNumber: 1,
      scorePercent: _lastResult?.scorePercent ?? 0,
      correctCount: _lastResult?.correctCount ?? 0,
      totalCount: _lastResult?.totalCount ?? 0,
      passed: _lastResult?.passed ?? false,
      submittedAt: DateTime.now(),
      questions: questions
          .map((q) => FinalExamReviewQuestion(
                id: q.id,
                text: q.text,
                qType: q.qType,
                subjectNameFa: q.subjectNameFa,
                options: q.options,
                correctIndex: q.isEssay ? -1 : 0,
                studentAnswerIndex: q.isEssay ? -1 : 0,
                isCorrect: q.isEssay ? null : true,
              ))
          .toList(),
    );
  }
}
