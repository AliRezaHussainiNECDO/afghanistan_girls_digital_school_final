import '../../domain/entities/exam_entities.dart';
import 'exams_remote_datasource.dart' show ExamsDataSource;

class ExamsMockDataSource implements ExamsDataSource {
  static const _exams = [
    ExamSummary(id: 'e1', subjectNameFa: 'ریاضی', type: ExamType.dailyQuiz, durationMinutes: 8, questionCount: 4),
    ExamSummary(id: 'e2', subjectNameFa: 'فزیک', type: ExamType.monthly, durationMinutes: 50, questionCount: 10),
    ExamSummary(id: 'e3', subjectNameFa: 'ادبیات دری', type: ExamType.homework, durationMinutes: 30, questionCount: 6),
  ];

  @override
  Future<List<ExamSummary>> getAvailableExams() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _exams;
  }

  @override
  Future<List<ExamQuestion>> getQuestions(String examId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final exam = _exams.firstWhere((e) => e.id == examId);
    return List.generate(
      exam.questionCount,
      (i) => ExamQuestion(
        id: '$examId-q${i + 1}',
        text: 'سؤال ${i + 1} — کدام گزینه صحیح است؟',
        options: const ['گزینهٔ الف', 'گزینهٔ ب', 'گزینهٔ ج', 'گزینهٔ د'],
        correctIndex: i % 4,
      ),
    );
  }

  @override
  Future<ExamResult> submitAnswers(String examId, Map<String, int> answers) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final questions = await getQuestions(examId);
    var correct = 0;
    for (final q in questions) {
      if (answers[q.id] == q.correctIndex) correct++;
    }
    final total = questions.length;
    return ExamResult(
      scorePercent: total == 0 ? 0 : (correct / total) * 100,
      correctCount: correct,
      totalCount: total,
    );
  }
}
