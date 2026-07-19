import 'package:dio/dio.dart';

import '../../../../../core/network/api_client.dart';
import '../../domain/entities/homework.dart';
import '../models/homework_model.dart';
import 'homework_datasource.dart';

/// پیاده‌سازی واقعی — روتر `homework` زیر `/api/v1` (بخش «مشق کاغذی +
/// نمره‌دهی هوشمند»، `backend/src/routes/homework.ts`).
class HomeworkRemoteDataSource implements HomeworkDataSource {
  final ApiClient _api;
  HomeworkRemoteDataSource(this._api);

  @override
  Future<HomeworkListResult> getHomeworks({HomeworkStatus? status, String? studentId}) async {
    final query = <String, dynamic>{
      if (status != null) 'status': status.name,
      if (studentId != null) 'studentId': studentId,
    };
    final data = await _api.get(
      '/homework',
      queryParameters: query.isEmpty ? null : query,
    );
    final map = data is Map ? data : <String, dynamic>{};
    final list = (map['homeworks'] as List? ?? [])
        .whereType<Map>()
        .map((j) => _withAbsoluteImage(HomeworkModel.fromJson(Map<String, dynamic>.from(j))))
        .toList();
    final avgRaw = map['averageScore'];
    return HomeworkListResult(
      classLevel: (map['classLevel'] as num?)?.toInt() ?? 7,
      averageScore: avgRaw is num ? avgRaw.toDouble() : null,
      homeworks: list,
    );
  }

  @override
  Future<Homework> getHomeworkById(String id) async {
    final data = await _api.get('/homework/$id');
    final map = data is Map ? data : <String, dynamic>{};
    final hw = map['homework'];
    if (hw is! Map) {
      throw const ApiException(message: 'پاسخ نامعتبر از سرور', type: ApiErrorType.unknown);
    }
    return _withAbsoluteImage(HomeworkModel.fromJson(Map<String, dynamic>.from(hw)));
  }

  @override
  Future<List<HomeworkReply>> getReplies(String homeworkId) async {
    final data = await _api.get('/homework/$homeworkId/replies');
    final map = data is Map ? data : <String, dynamic>{};
    return (map['replies'] as List? ?? [])
        .whereType<Map>()
        .map((j) => HomeworkReplyModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  @override
  Future<Homework> submitPhoto({
    required String homeworkId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  }) async {
    // آپلود چندبخشی (multipart/form-data) — دقیقاً هماهنگ با انتظار سرور
    // (`form.get('file')` در `routes/homework.ts`، همان الگوی آپلود کتاب در
    // `academy.ts`/`media.ts`).
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: DioMediaType.parse(contentType)),
    });
    final data = await _api.raw.post(
      '/homework/$homeworkId/submit',
      data: form,
    );
    final map = data.data is Map ? data.data as Map : <String, dynamic>{};
    final hw = map['homework'];
    if (hw is! Map) {
      throw const ApiException(message: 'پاسخ نامعتبر از سرور', type: ApiErrorType.unknown);
    }
    return _withAbsoluteImage(HomeworkModel.fromJson(Map<String, dynamic>.from(hw)));
  }

  @override
  Future<List<HomeworkReply>> sendReply({required String homeworkId, required String text}) async {
    final data = await _api.post('/homework/$homeworkId/reply', data: {'text': text});
    final map = data is Map ? data : <String, dynamic>{};
    return (map['replies'] as List? ?? [])
        .whereType<Map>()
        .map((j) => HomeworkReplyModel.fromJson(Map<String, dynamic>.from(j)))
        .toList();
  }

  /// آدرس نسبی سرور (مثل `/files/homework/...`) را به آدرس کامل تبدیل می‌کند
  /// — همان الگوی `_absoluteUrl` در AuthRemoteDataSource.
  Homework _withAbsoluteImage(Homework hw) {
    if (hw.studentImageUrl.isEmpty ||
        hw.studentImageUrl.startsWith('http://') ||
        hw.studentImageUrl.startsWith('https://')) {
      return hw;
    }
    return HomeworkModel(
      id: hw.id,
      studentId: hw.studentId,
      subjectId: hw.subjectId,
      subjectNameFa: hw.subjectNameFa,
      chapterId: hw.chapterId,
      lessonId: hw.lessonId,
      classLevel: hw.classLevel,
      questionText: hw.questionText,
      hintText: hw.hintText,
      status: hw.status,
      studentImageUrl: '$kApiBaseUrl${hw.studentImageUrl}',
      extractedText: hw.extractedText,
      aiScore: hw.aiScore,
      aiFeedback: hw.aiFeedback,
      createdAt: hw.createdAt,
      submittedAt: hw.submittedAt,
      gradedAt: hw.gradedAt,
    );
  }
}
