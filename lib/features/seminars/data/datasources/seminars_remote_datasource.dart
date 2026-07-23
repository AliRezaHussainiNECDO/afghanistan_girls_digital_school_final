import '../../../../core/network/api_client.dart';
import '../../../../shared_models/seminar.dart';

/// تبدیل JSON سرور به `Seminar` — مشترک بین همهٔ DataSourceهای ریموت سمینار
/// (شاگرد/والد، استاد، مدیر).
Seminar seminarFromJson(dynamic e) => Seminar(
      id: e['id'] as String,
      title: e['title'] as String? ?? '',
      description: e['description'] as String? ?? '',
      instructorId: e['instructorId'] as String? ?? '',
      instructorName: e['instructorName'] as String? ?? '',
      scheduledStart:
          DateTime.tryParse(e['scheduledStart'] as String? ?? '') ?? DateTime.now(),
      durationMinutes: (e['durationMinutes'] as num?)?.toInt() ?? 45,
      status: seminarStatusFromName(e['status'] as String?),
      capacity: (e['capacity'] as num?)?.toInt(),
      audience:
          e['audience'] == 'parents' ? SeminarAudience.parents : SeminarAudience.students,
      meetingLink: e['meetingLink'] as String? ?? '',
      streamUid: e['streamUid'] as String? ?? '',
      streamPlaybackUrl: e['streamPlaybackUrl'] as String? ?? '',
      streamDashUrl: e['streamDashUrl'] as String? ?? '',
      registeredUserIds:
          ((e['registeredUserIds'] as List?) ?? []).map((x) => x.toString()).toSet(),
      aiReportFa: e['aiReportFa'] as String? ?? '',
      archivedAt: DateTime.tryParse(e['archivedAt'] as String? ?? ''),
    );

SeminarStatus seminarStatusFromName(String? s) => SeminarStatus.values.firstWhere(
      (v) => v.name == s,
      orElse: () => SeminarStatus.published,
    );

/// قرارداد مشترک DataSource سمینار (نمای شاگرد/والد) — Mock و Remote هر دو
/// آن را پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class SeminarsDataSource {
  Future<List<Seminar>> getUpcoming(SeminarAudience audience);
  Future<Seminar> getById(String id);
  Future<void> register(String seminarId, String userId);

  /// تغییر وضعیت (شروع/پایان دستی) — برای اتاق داخلی سمینار (فال‌بک بدون
  /// Cloudflare Stream) وقتی میزبان (استاد/مدیر) شروع/پایان را می‌زند، تا
  /// وضعیت واقعاً روی سرور/پایگاه‌داده ثبت و برای همهٔ نقش‌ها هماهنگ شود.
  Future<void> setStatus(String seminarId, SeminarStatus status);
}

/// پیاده‌سازی واقعی — روتر seminars زیر `/api/v1` (بخش ۱۲/۱۹.۸ سند).
class SeminarsRemoteDataSource implements SeminarsDataSource {
  final ApiClient _api;
  SeminarsRemoteDataSource(this._api);

  @override
  Future<List<Seminar>> getUpcoming(SeminarAudience audience) async {
    final data = await _api.get('/seminars', queryParameters: {'audience': audience.name});
    final list = (data['seminars'] as List? ?? []);
    return list.map(seminarFromJson).toList();
  }

  @override
  Future<Seminar> getById(String id) async {
    final data = await _api.get('/seminars/$id');
    return seminarFromJson(data['seminar']);
  }

  @override
  Future<void> register(String seminarId, String userId) async {
    await _api.post('/seminars/$seminarId/register');
  }

  @override
  Future<void> setStatus(String seminarId, SeminarStatus status) async {
    await _api.patch('/seminars/$seminarId/status', data: {'status': status.name});
  }
}
