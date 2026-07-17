import '../../../core/network/api_client.dart';
import '../domain/advisor_entities.dart';

/// پیاده‌سازی واقعی — روتر advisor زیر `/api/v1` (رفع اشکال حیاتی امنیتی:
/// قبلاً این گفتگو فقط در حافظهٔ محلی گوشی بود و به مدیر واقعی نمی‌رسید).
class AdvisorRemoteDataSource {
  final ApiClient _api;
  AdvisorRemoteDataSource(this._api);

  AdvisorMessage _fromJson(Map<String, dynamic> m) => AdvisorMessage(
        id: m['id'] as String,
        studentId: m['studentId'] as String,
        studentName: (m['studentName'] ?? '') as String,
        role: m['role'] == 'advisor' ? AdvisorRole.advisor : AdvisorRole.student,
        text: (m['text'] ?? '') as String,
        createdAt: DateTime.tryParse((m['createdAt'] as String? ?? '').replaceFirst(' ', 'T')) ?? DateTime.now(),
        flagged: m['flagged'] == true,
        topic: (m['topic'] ?? 'عمومی') as String,
      );

  /// تاریخچهٔ گفتگوی شاگردِ جاری.
  Future<List<AdvisorMessage>> fetchOwnMessages() async {
    final data = await _api.get('/advisor/messages');
    return (data as List? ?? []).map((e) => _fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// ثبت یک پیام (شاگرد یا پاسخ مشاور — که روی کلاینت تولید می‌شود) روی سرور.
  Future<void> postMessage({
    required AdvisorRole role,
    required String text,
    required String topic,
    bool flagged = false,
    String? studentName,
  }) async {
    await _api.post('/advisor/messages', data: {
      'role': role == AdvisorRole.advisor ? 'advisor' : 'student',
      'text': text,
      'topic': topic,
      'flagged': flagged,
      if (studentName != null) 'studentName': studentName,
    });
  }

  /// فهرست گفتگوها برای نمای مدیر.
  Future<List<AdvisorThreadSummary>> fetchThreads() async {
    final data = await _api.get('/admin/advisor/threads');
    return (data as List? ?? []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return AdvisorThreadSummary(
        studentId: m['studentId'] as String,
        studentName: (m['studentName'] ?? '') as String,
        messageCount: (m['messageCount'] as num?)?.toInt() ?? 0,
        lastAt: DateTime.tryParse((m['lastAt'] as String? ?? '').replaceFirst(' ', 'T')) ?? DateTime.now(),
        hasFlag: m['hasFlag'] == true,
      );
    }).toList();
  }

  /// تاریخچهٔ یک شاگرد مشخص برای نمای مدیر.
  Future<List<AdvisorMessage>> fetchStudentMessages(String studentId) async {
    final data = await _api.get('/admin/advisor/students/$studentId/messages');
    return (data as List? ?? []).map((e) => _fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}
