import '../../domain/entities/final_exam_entities.dart';
import 'admin_final_exam_remote_datasource.dart' show AdminFinalExamDataSource;

/// نسخهٔ Mock — برای پیش‌نمایش بخش مدیریت بدون سرور واقعی.
class AdminFinalExamMockDataSource implements AdminFinalExamDataSource {
  final List<AdminFinalExamRow> _exams = [];
  final Map<String, List<AdminFinalExamQuestionRow>> _questions = {};
  int _seq = 0;

  @override
  Future<List<AdminFinalExamRow>> getFinalExams({int? gradeNumber}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return gradeNumber == null ? _exams : _exams.where((e) => e.gradeNumber == gradeNumber).toList();
  }

  @override
  Future<AdminFinalExamRow> createFinalExam({required int gradeNumber, required String academicYear, required String title}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final row = AdminFinalExamRow(
      id: 'fe-mock-${_seq++}',
      gradeNumber: gradeNumber,
      academicYear: academicYear,
      title: title,
      status: FinalExamAdminStatus.draft,
      passThreshold: 80,
      questionCount: 0,
      createdAt: DateTime.now(),
    );
    _exams.add(row);
    return row;
  }

  @override
  Future<void> setStatus(String id, FinalExamAdminStatus status) async {
    final i = _exams.indexWhere((e) => e.id == id);
    if (i == -1) return;
    final old = _exams[i];
    _exams[i] = AdminFinalExamRow(
      id: old.id,
      gradeNumber: old.gradeNumber,
      academicYear: old.academicYear,
      title: old.title,
      status: status,
      passThreshold: old.passThreshold,
      questionCount: old.questionCount,
      createdAt: old.createdAt,
    );
  }

  @override
  Future<void> deleteFinalExam(String id) async {
    _exams.removeWhere((e) => e.id == id);
    _questions.remove(id);
  }

  @override
  Future<List<AdminFinalExamQuestionRow>> getQuestions(String finalExamId) async => _questions[finalExamId] ?? [];

  @override
  Future<AdminFinalExamQuestionRow> saveQuestion(AdminFinalExamQuestionRow row) async {
    final list = _questions.putIfAbsent(row.finalExamId, () => []);
    final saved = row.id.startsWith('new') ? AdminFinalExamQuestionRow(
      id: 'q-mock-${_seq++}',
      finalExamId: row.finalExamId,
      subjectId: row.subjectId,
      subjectNameFa: row.subjectNameFa,
      qType: row.qType,
      text: row.text,
      options: row.options,
      correctIndex: row.correctIndex,
      answerText: row.answerText,
      orderIndex: row.orderIndex,
    ) : row;
    list.removeWhere((q) => q.id == saved.id);
    list.add(saved);
    return saved;
  }

  @override
  Future<void> deleteQuestion(String id) async {
    for (final list in _questions.values) {
      list.removeWhere((q) => q.id == id);
    }
  }

  @override
  Future<GenerateFinalExamResult> generateQuestions(String finalExamId, {int perSubjectCount = 3}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return const GenerateFinalExamResult(savedCount: 9, failedSubjects: []);
  }
}
