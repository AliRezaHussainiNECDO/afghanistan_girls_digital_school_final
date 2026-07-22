import '../../domain/entities/exam_entities.dart';
import 'exams_remote_datasource.dart' show ExamsDataSource;

class ExamsMockDataSource implements ExamsDataSource {
  static const _exams = [
    ExamSummary(id: 'e1', subjectNameFa: 'ریاضی', type: ExamType.dailyQuiz, durationMinutes: 8, questionCount: 4),
    ExamSummary(id: 'e2', subjectNameFa: 'فزیک', type: ExamType.monthly, durationMinutes: 50, questionCount: 10),
    ExamSummary(id: 'e3', subjectNameFa: 'ادبیات دری', type: ExamType.homework, durationMinutes: 30, questionCount: 6),
  ];

  /// امتحان‌هایی که در همین جلسهٔ Mock «داده شده‌اند» — دیگر در فهرست
  /// «قابل‌شروع» برنمی‌گردند، دقیقاً مثل رفتار واقعی سرور.
  static final List<ExamResultSummary> _mockResults = [];

  @override
  Future<List<ExamSummary>> getAvailableExams() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final attemptedIds = _mockResults.map((r) => r.examId).toSet();
    return _exams.where((e) => !attemptedIds.contains(e.id)).toList();
  }

  @override
  Future<List<ExamQuestion>> getQuestions(String examId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final exam = _exams.firstWhere((e) => e.id == examId);
    // برای پیش‌نمایش، هر سه نوع سؤال (migration 0030) به نوبت تولید می‌شود.
    return List.generate(exam.questionCount, (i) {
      switch (i % 3) {
        case 1:
          return ExamQuestion(
            id: '$examId-q${i + 1}',
            text: 'سؤال ${i + 1} — این گزاره صحیح است یا غلط؟',
            qType: QuestionType.trueFalse,
            options: const ['صحیح', 'غلط'],
            correctIndex: i % 2,
          );
        case 2:
          return ExamQuestion(
            id: '$examId-q${i + 1}',
            text: 'سؤال ${i + 1} — به‌صورت تشریحی توضیح دهید.',
            qType: QuestionType.essay,
            options: const [],
            correctIndex: -1,
          );
        default:
          return ExamQuestion(
            id: '$examId-q${i + 1}',
            text: 'سؤال ${i + 1} — کدام گزینه صحیح است؟',
            options: const ['گزینهٔ الف', 'گزینهٔ ب', 'گزینهٔ ج', 'گزینهٔ د'],
            correctIndex: i % 4,
          );
      }
    });
  }

  @override
  Future<ExamResult> submitAnswers(String examId, Map<String, int> answers, Map<String, String> textAnswers) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final questions = await getQuestions(examId);
    var correct = 0;
    var total = 0;
    for (final q in questions) {
      if (q.isEssay) {
        // Mock: پاسخ تشریحیِ غیرخالی نمرهٔ کامل می‌گیرد (نمره‌دهی واقعی AI سمت سرور است).
        if ((textAnswers[q.id] ?? '').trim().isNotEmpty) {
          correct++;
          total++;
        }
      } else {
        if (answers[q.id] == q.correctIndex) correct++;
        total++;
      }
    }
    final scorePercent = total == 0 ? 0.0 : (correct / total) * 100;
    final exam = _exams.firstWhere((e) => e.id == examId);
    final attemptId = 'mock-attempt-$examId-${DateTime.now().millisecondsSinceEpoch}';
    // مثل سرور واقعی: این تلاش ثبت می‌شود تا امتحان دیگر در فهرست
    // «قابل‌شروع» دیده نشود و به‌جایش در «نتایج امتحانات» ظاهر شود.
    _mockResults.insert(
      0,
      ExamResultSummary(
        attemptId: attemptId,
        examId: examId,
        examTitle: '${exam.subjectNameFa} — ${exam.type.name}',
        subjectNameFa: exam.subjectNameFa,
        gradeNumber: exam.gradeNumber,
        type: exam.type,
        scorePercent: scorePercent,
        correctCount: correct,
        totalCount: total,
        passed: scorePercent >= kExamPassPercent,
        submittedAt: DateTime.now(),
      ),
    );
    _mockAttemptAnswers[attemptId] = _MockAttemptData(questions: questions, answers: answers, textAnswers: textAnswers);
    return ExamResult(
      scorePercent: scorePercent,
      correctCount: correct,
      totalCount: total,
      attemptId: attemptId,
      passed: scorePercent >= kExamPassPercent,
    );
  }

  static final Map<String, _MockAttemptData> _mockAttemptAnswers = {};

  @override
  Future<List<ExamResultSummary>> getMyResults({String? studentId}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return List.unmodifiable(_mockResults);
  }

  @override
  Future<ExamAttemptReview> getAttemptReview(String attemptId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final summary = _mockResults.firstWhere((r) => r.attemptId == attemptId);
    final data = _mockAttemptAnswers[attemptId];
    final questions = (data?.questions ?? const <ExamQuestion>[]).map((q) {
      if (q.isEssay) {
        final text = data?.textAnswers[q.id] ?? '';
        return ExamReviewQuestion(
          id: q.id,
          text: q.text,
          qType: q.qType,
          options: const [],
          correctIndex: -1,
          studentAnswerIndex: -1,
          studentAnswerText: text,
          isCorrect: text.trim().isNotEmpty,
        );
      }
      final studentIdx = data?.answers[q.id] ?? -1;
      return ExamReviewQuestion(
        id: q.id,
        text: q.text,
        qType: q.qType,
        options: q.options,
        correctIndex: q.correctIndex,
        studentAnswerIndex: studentIdx,
        isCorrect: studentIdx == q.correctIndex,
      );
    }).toList();
    return ExamAttemptReview(
      attemptId: summary.attemptId,
      examId: summary.examId,
      examTitle: summary.examTitle,
      subjectNameFa: summary.subjectNameFa,
      gradeNumber: summary.gradeNumber,
      type: summary.type,
      scorePercent: summary.scorePercent,
      correctCount: summary.correctCount,
      totalCount: summary.totalCount,
      submittedAt: summary.submittedAt,
      questions: questions,
      passed: summary.passed,
    );
  }
}

class _MockAttemptData {
  final List<ExamQuestion> questions;
  final Map<String, int> answers;
  final Map<String, String> textAnswers;
  const _MockAttemptData({required this.questions, required this.answers, required this.textAnswers});
}
