import '../../../../exams/domain/entities/exam_entities.dart';
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
