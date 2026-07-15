import '../../../../../core/network/api_client.dart';
import '../../domain/entities/ai_teacher_config.dart';
import '../../domain/entities/ai_teacher_stats.dart';
import 'ai_teacher_management_data_source.dart';

/// پیاده‌سازی واقعی — `GET/PATCH /api/v1/ai-teacher/personas` (مهاجرت ۰۰۱۹).
/// رفع اشکال: قبلاً «مدیریت معلم هوشمند» فقط در SharedPreferences هر دستگاه
/// ذخیره می‌شد و هرگز به سرور/دیتابیس وصل نبود؛ این کلاس آن اتصال را برقرار
/// می‌کند تا تنظیمات مدیر واقعاً روی گفت‌وگوی شاگرد اثر بگذارد.
class AiTeacherManagementRemoteDataSource implements AiTeacherManagementDataSource {
  final ApiClient _api;
  const AiTeacherManagementRemoteDataSource(this._api);

  @override
  Future<List<AiTeacherConfig>> getConfigs() async {
    final data = await _api.get('/ai-teacher/personas');
    final list = (data is Map ? data['personas'] as List? : null) ?? const [];
    return list
        .map((e) => _fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  @override
  Future<String?> personaFor(String subjectId) async {
    final data = await _api.get('/ai-teacher/personas/$subjectId');
    return (data is Map ? data['personaDescription'] as String? : null);
  }

  @override
  Future<void> updatePersona(String subjectId, String newDescription) async {
    await _api.patch('/admin/ai-teacher/personas/$subjectId', data: {
      'personaDescription': newDescription,
    });
  }

  AiTeacherConfig _fromJson(Map<String, dynamic> j) => AiTeacherConfig(
        subjectId: j['subjectId'] as String,
        subjectNameFa: j['subjectNameFa'] as String? ?? '',
        personaDescription: j['personaDescription'] as String? ?? '',
        promptVersion: (j['promptVersion'] as num?)?.toInt() ?? 1,
      );

  @override
  Future<AiTeacherStats> getStats() async {
    final data = await _api.get('/admin/ai-teacher/stats');
    if (data is! Map) return AiTeacherStats.empty;
    final bySubjectRaw = (data['bySubject'] as List?) ?? const [];
    return AiTeacherStats(
      totalMessages: (data['totalMessages'] as num?)?.toInt() ?? 0,
      messagesToday: (data['messagesToday'] as num?)?.toInt() ?? 0,
      activeStudentsToday: (data['activeStudentsToday'] as num?)?.toInt() ?? 0,
      activeStudentsWeek: (data['activeStudentsWeek'] as num?)?.toInt() ?? 0,
      accuracyPercent: (data['accuracyPercent'] as num?)?.toDouble(),
      totalAnsweredAttempts: (data['totalAnsweredAttempts'] as num?)?.toInt() ?? 0,
      embeddingCoveragePercent: (data['embeddingCoveragePercent'] as num?)?.toDouble(),
      bySubject: bySubjectRaw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((j) => AiTeacherSubjectUsage(
                subjectId: j['subjectId'] as String? ?? '',
                subjectNameFa: j['subjectNameFa'] as String? ?? (j['subjectId'] as String? ?? ''),
                messageCount: (j['messageCount'] as num?)?.toInt() ?? 0,
              ))
          .toList(),
    );
  }
}
