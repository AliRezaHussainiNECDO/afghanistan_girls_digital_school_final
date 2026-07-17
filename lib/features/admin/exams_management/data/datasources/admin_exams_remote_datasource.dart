import '../../../../../core/network/api_client.dart';
import '../../domain/entities/admin_exam_entities.dart';

/// قرارداد مشترک DataSource مدیریتِ امتحان/سؤال — Mock و Remote هر دو آن را
/// پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class AdminExamsDataSource {
  Future<List<AdminExamRow>> getExams();
  Future<AdminExamRow> saveExam(AdminExamRow row);
  Future<void> setExamStatus(String id, ExamAdminStatus status);
  Future<void> deleteExam(String id);

  Future<List<AdminQuestionRow>> getQuestions(String examId);
  Future<AdminQuestionRow> saveQuestion(AdminQuestionRow row);
  Future<void> deleteQuestion(String id);
}

/// پیاده‌سازی واقعی — روتر `/api/v1/admin/exams*` و
/// `/api/v1/admin/exams/:examId/questions*` (backend/src/routes/exams.ts).
/// فقط مدیر (JWT با نقش super_admin) — رفع اشکال: قبلاً هیچ Endpointای
/// برای ساخت امتحان/سؤال از داخل برنامه وجود نداشت.
class AdminExamsRemoteDataSource implements AdminExamsDataSource {
  final ApiClient _api;
  AdminExamsRemoteDataSource(this._api);

  @override
  Future<List<AdminExamRow>> getExams() async {
    final data = await _api.get('/admin/exams');
    return ((data['exams'] as List?) ?? []).map(_examFrom).toList();
  }

  @override
  Future<AdminExamRow> saveExam(AdminExamRow row) async {
    final data = await _api.post('/admin/exams', data: {
      if (!row.id.startsWith('new')) 'id': row.id,
      'subjectId': row.subjectId,
      'gradeNumber': row.gradeNumber,
      'type': row.type.key,
      'title': row.title,
      'durationMinutes': row.durationMinutes,
      'status': row.status.key,
    });
    return _examFrom(data['exam']);
  }

  @override
  Future<void> setExamStatus(String id, ExamAdminStatus status) =>
      _api.patch('/admin/exams/$id/status', data: {'status': status.key});

  @override
  Future<void> deleteExam(String id) => _api.delete('/admin/exams/$id');

  @override
  Future<List<AdminQuestionRow>> getQuestions(String examId) async {
    final data = await _api.get('/admin/exams/$examId/questions');
    return ((data['questions'] as List?) ?? []).map(_questionFrom).toList();
  }

  @override
  Future<AdminQuestionRow> saveQuestion(AdminQuestionRow row) async {
    final data = await _api.post('/admin/exams/${row.examId}/questions', data: {
      if (!row.id.startsWith('new')) 'id': row.id,
      'text': row.text,
      'options': row.options,
      'correctIndex': row.correctIndex,
      'orderIndex': row.orderIndex,
    });
    return _questionFrom(data['question']);
  }

  @override
  Future<void> deleteQuestion(String id) => _api.delete('/admin/questions/$id');

  AdminExamRow _examFrom(dynamic e) => AdminExamRow(
        id: e['id'] as String,
        subjectId: e['subjectId'] as String? ?? '',
        subjectNameFa: e['subjectNameFa'] as String? ?? '',
        gradeNumber: (e['gradeNumber'] as num?)?.toInt() ?? 7,
        type: ExamTypeX.fromKey(e['type'] as String? ?? 'daily_quiz'),
        title: e['title'] as String? ?? '',
        durationMinutes: (e['durationMinutes'] as num?)?.toInt() ?? 10,
        status: ExamAdminStatusX.fromKey(e['status'] as String? ?? 'draft'),
        questionCount: (e['questionCount'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(e['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  AdminQuestionRow _questionFrom(dynamic e) => AdminQuestionRow(
        id: e['id'] as String,
        examId: e['examId'] as String? ?? '',
        text: e['text'] as String? ?? '',
        options: ((e['options'] as List?) ?? []).map((o) => o.toString()).toList(),
        correctIndex: (e['correctIndex'] as num?)?.toInt() ?? 0,
        orderIndex: (e['orderIndex'] as num?)?.toInt() ?? 0,
      );
}
