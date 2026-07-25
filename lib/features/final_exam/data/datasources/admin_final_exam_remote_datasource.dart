import 'package:dio/dio.dart' show Options;
import '../../../../core/network/api_client.dart';
import '../../domain/entities/final_exam_entities.dart';

abstract class AdminFinalExamDataSource {
  Future<List<AdminFinalExamRow>> getFinalExams({int? gradeNumber});
  Future<AdminFinalExamRow> createFinalExam({required int gradeNumber, required String academicYear, required String title});
  Future<void> setStatus(String id, FinalExamAdminStatus status);
  Future<void> deleteFinalExam(String id);

  Future<List<AdminFinalExamQuestionRow>> getQuestions(String finalExamId);
  Future<AdminFinalExamQuestionRow> saveQuestion(AdminFinalExamQuestionRow row);
  Future<void> deleteQuestion(String id);

  Future<GenerateFinalExamResult> generateQuestions(String finalExamId, {int perSubjectCount});
}

/// پیاده‌سازی واقعی — `backend/src/routes/finalExams.ts` (بخش `/admin/final-exams*`).
class AdminFinalExamRemoteDataSource implements AdminFinalExamDataSource {
  final ApiClient _api;
  AdminFinalExamRemoteDataSource(this._api);

  @override
  Future<List<AdminFinalExamRow>> getFinalExams({int? gradeNumber}) async {
    final data = await _api.get('/admin/final-exams', queryParameters: gradeNumber != null ? {'grade': gradeNumber} : null);
    return ((data['finalExams'] as List?) ?? []).map(_examFrom).toList();
  }

  @override
  Future<AdminFinalExamRow> createFinalExam({required int gradeNumber, required String academicYear, required String title}) async {
    final data = await _api.post('/admin/final-exams', data: {
      'gradeNumber': gradeNumber,
      'academicYear': academicYear,
      'title': title,
    });
    return _examFrom(data['finalExam']);
  }

  @override
  Future<void> setStatus(String id, FinalExamAdminStatus status) =>
      _api.patch('/admin/final-exams/$id/status', data: {'status': status.key});

  @override
  Future<void> deleteFinalExam(String id) => _api.delete('/admin/final-exams/$id');

  @override
  Future<List<AdminFinalExamQuestionRow>> getQuestions(String finalExamId) async {
    final data = await _api.get('/admin/final-exams/$finalExamId/questions');
    return ((data['questions'] as List?) ?? []).map(_questionFrom).toList();
  }

  @override
  Future<AdminFinalExamQuestionRow> saveQuestion(AdminFinalExamQuestionRow row) async {
    final data = await _api.post('/admin/final-exams/${row.finalExamId}/questions', data: {
      if (!row.id.startsWith('new')) 'id': row.id,
      'subjectId': row.subjectId,
      'qType': row.qType.key,
      'text': row.text,
      'options': row.options,
      'correctIndex': row.correctIndex,
      'answerText': row.answerText,
      'orderIndex': row.orderIndex,
    });
    return _questionFrom(data['question']);
  }

  @override
  Future<void> deleteQuestion(String id) => _api.delete('/admin/final-exam-questions/$id');

  @override
  Future<GenerateFinalExamResult> generateQuestions(String finalExamId, {int perSubjectCount = 3}) async {
    // این درخواست هم‌زمان برای همهٔ مضامین صنف با AI سؤال می‌سازد — معمولاً
    // بیشتر از مهلت پیش‌فرض شبکه (۲۰ ثانیه) طول می‌کشد؛ مهلت طولانی‌تری
    // فقط برای همین یک تماس تنظیم شده (نه کل اپ) تا زودتر از موعد timeout نخورد.
    final data = await _api.post(
      '/admin/final-exams/$finalExamId/generate-questions',
      data: {'perSubjectCount': perSubjectCount},
      options: Options(receiveTimeout: const Duration(seconds: 60), sendTimeout: const Duration(seconds: 60)),
    );
    return GenerateFinalExamResult(
      savedCount: (data['savedCount'] as num?)?.toInt() ?? 0,
      failedSubjects: ((data['failedSubjects'] as List?) ?? []).map((e) => e.toString()).toList(),
    );
  }

  AdminFinalExamRow _examFrom(dynamic e) => AdminFinalExamRow(
        id: e['id'] as String,
        gradeNumber: (e['gradeNumber'] as num?)?.toInt() ?? 0,
        academicYear: e['academicYear'] as String? ?? '',
        title: e['title'] as String? ?? '',
        status: FinalExamAdminStatusX.fromKey(e['status'] as String? ?? 'draft'),
        passThreshold: (e['passThreshold'] as num?)?.toDouble() ?? 80,
        questionCount: (e['questionCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(e['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  AdminFinalExamQuestionRow _questionFrom(dynamic e) => AdminFinalExamQuestionRow(
        id: e['id'] as String,
        finalExamId: e['finalExamId'] as String? ?? '',
        subjectId: e['subjectId'] as String? ?? '',
        subjectNameFa: e['subjectNameFa'] as String? ?? '',
        qType: QuestionTypeX.fromKey(e['qType'] as String?),
        text: e['text'] as String? ?? '',
        options: ((e['options'] as List?) ?? []).map((o) => o.toString()).toList(),
        correctIndex: (e['correctIndex'] as num?)?.toInt() ?? -1,
        answerText: e['answerText'] as String? ?? '',
        orderIndex: (e['orderIndex'] as num?)?.toInt() ?? 0,
      );
}
