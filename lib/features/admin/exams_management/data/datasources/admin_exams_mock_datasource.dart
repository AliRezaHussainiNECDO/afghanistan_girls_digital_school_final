import '../../domain/entities/admin_exam_entities.dart';
import 'admin_exams_remote_datasource.dart';

/// دادهٔ Mock فاز ۱ — فقط برای پیش‌نمایش وقتی `kUseLiveBackend = false`
/// است. تغییرات فقط در حافظهٔ همین نشست باقی می‌ماند.
class AdminExamsMockDataSource implements AdminExamsDataSource {
  final List<AdminExamRow> _exams = [
    AdminExamRow(
      id: 'ex-g7-math-q1',
      subjectId: 'math',
      subjectNameFa: 'ریاضی',
      gradeNumber: 7,
      type: ExamType.dailyQuiz,
      title: 'کوییز روزانهٔ ریاضی — اعداد صحیح',
      durationMinutes: 8,
      status: ExamAdminStatus.published,
      questionCount: 4,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];
  final Map<String, List<AdminQuestionRow>> _questions = {
    'ex-g7-math-q1': [
      const AdminQuestionRow(
        id: 'q-m1',
        examId: 'ex-g7-math-q1',
        text: 'حاصل ۳ + (−۵) چند است؟',
        options: ['۲', '−۲', '۸', '−۸'],
        correctIndex: 1,
        orderIndex: 1,
      ),
    ],
  };

  @override
  Future<List<AdminExamRow>> getExams() async => List.unmodifiable(_exams);

  @override
  Future<AdminExamRow> saveExam(AdminExamRow row) async {
    final idx = _exams.indexWhere((e) => e.id == row.id);
    if (idx == -1) {
      final saved = AdminExamRow(
        id: 'exam_${DateTime.now().microsecondsSinceEpoch}',
        subjectId: row.subjectId,
        subjectNameFa: row.subjectNameFa,
        gradeNumber: row.gradeNumber,
        type: row.type,
        title: row.title,
        durationMinutes: row.durationMinutes,
        status: row.status,
        questionCount: 0,
        createdAt: DateTime.now(),
      );
      _exams.add(saved);
      _questions[saved.id] = [];
      return saved;
    }
    _exams[idx] = row;
    return row;
  }

  @override
  Future<void> setExamStatus(String id, ExamAdminStatus status) async {
    final idx = _exams.indexWhere((e) => e.id == id);
    if (idx != -1) _exams[idx] = _exams[idx].copyWith(status: status);
  }

  @override
  Future<void> deleteExam(String id) async {
    _exams.removeWhere((e) => e.id == id);
    _questions.remove(id);
  }

  @override
  Future<List<AdminQuestionRow>> getQuestions(String examId) async =>
      List.unmodifiable(_questions[examId] ?? const []);

  @override
  Future<AdminQuestionRow> saveQuestion(AdminQuestionRow row) async {
    final list = _questions.putIfAbsent(row.examId, () => []);
    final idx = list.indexWhere((q) => q.id == row.id);
    final saved = idx == -1
        ? AdminQuestionRow(
            id: 'q_${DateTime.now().microsecondsSinceEpoch}',
            examId: row.examId,
            text: row.text,
            options: row.options,
            correctIndex: row.correctIndex,
            orderIndex: row.orderIndex == 0 ? list.length + 1 : row.orderIndex,
          )
        : row;
    if (idx == -1) {
      list.add(saved);
    } else {
      list[idx] = saved;
    }
    final examIdx = _exams.indexWhere((e) => e.id == row.examId);
    if (examIdx != -1) {
      _exams[examIdx] = _exams[examIdx].copyWith(questionCount: list.length);
    }
    return saved;
  }

  @override
  Future<List<AdminQuestionRow>> generateQuestions(GenerateQuestionsParams params) async {
    // Mock: سؤالات نمونهٔ محلی — تولید واقعی AI فقط با backend زنده.
    await Future.delayed(const Duration(milliseconds: 600));
    final list = _questions.putIfAbsent(params.examId, () => []);
    final generated = <AdminQuestionRow>[];
    var order = list.length;
    AdminQuestionRow make(QuestionType t, int i) {
      order += 1;
      final id = 'q_ai_${DateTime.now().microsecondsSinceEpoch}_$order';
      switch (t) {
        case QuestionType.trueFalse:
          return AdminQuestionRow(
            id: id,
            examId: params.examId,
            text: 'سؤال صحیح/غلط نمونهٔ ${i + 1}${params.topic.isNotEmpty ? ' — ${params.topic}' : ''}',
            qType: QuestionType.trueFalse,
            options: const ['صحیح', 'غلط'],
            correctIndex: i % 2,
            orderIndex: order,
          );
        case QuestionType.essay:
          return AdminQuestionRow(
            id: id,
            examId: params.examId,
            text: 'سؤال تشریحی نمونهٔ ${i + 1}${params.topic.isNotEmpty ? ' — ${params.topic}' : ''}',
            qType: QuestionType.essay,
            options: const [],
            correctIndex: -1,
            orderIndex: order,
            answerText: 'پاسخ نمونهٔ تولیدشده برای کلید نمره‌دهی.',
          );
        case QuestionType.mcq:
          return AdminQuestionRow(
            id: id,
            examId: params.examId,
            text: 'سؤال چهارگزینه‌ای نمونهٔ ${i + 1}${params.topic.isNotEmpty ? ' — ${params.topic}' : ''}',
            options: const ['گزینهٔ الف', 'گزینهٔ ب', 'گزینهٔ ج', 'گزینهٔ د'],
            correctIndex: i % 4,
            orderIndex: order,
          );
      }
    }

    for (var i = 0; i < params.mcqCount; i++) {
      generated.add(make(QuestionType.mcq, i));
    }
    for (var i = 0; i < params.trueFalseCount; i++) {
      generated.add(make(QuestionType.trueFalse, i));
    }
    for (var i = 0; i < params.essayCount; i++) {
      generated.add(make(QuestionType.essay, i));
    }
    list.addAll(generated);
    final examIdx = _exams.indexWhere((e) => e.id == params.examId);
    if (examIdx != -1) {
      _exams[examIdx] = _exams[examIdx].copyWith(questionCount: list.length);
    }
    return generated;
  }

  @override
  Future<void> deleteQuestion(String id) async {
    for (final entry in _questions.entries) {
      final before = entry.value.length;
      entry.value.removeWhere((q) => q.id == id);
      if (entry.value.length != before) {
        final examIdx = _exams.indexWhere((e) => e.id == entry.key);
        if (examIdx != -1) {
          _exams[examIdx] = _exams[examIdx].copyWith(questionCount: entry.value.length);
        }
        break;
      }
    }
  }
}
