import '../../../../../core/network/api_client.dart';
import '../../domain/entities/arena_event_list_item.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DataSource «زمان‌بندی میدان ستارگان» — `GET/POST/DELETE /api/v1/admin/live-arena/*`
/// (نیاز به مجوز 'manage_live_arena'، رجوع کن backend/src/routes/liveArena.ts).
/// ═══════════════════════════════════════════════════════════════════════════
class AdminLiveArenaRemoteDataSource {
  final ApiClient _api;
  const AdminLiveArenaRemoteDataSource(this._api);

  Future<AdminArenaEventsPage> fetchEvents() async {
    final data = await _api.get('/admin/live-arena/events');
    return AdminArenaEventsPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// `startsAt` باید ISO-8601 با منطقهٔ زمانی باشد (`DateTime.toIso8601String`
  /// روی یک `DateTime` غیر-UTC هم مقدار قابل‌قبولی برای `new Date()` سمت
  /// سرور تولید می‌کند). خروجی: شناسهٔ رویداد تازه‌ساخته‌شده.
  Future<String> schedule({
    required DateTime startsAt,
    String? titleFa,
    int? durationMinutes,
    required int minRankNo,
    required int questionCount,
    required int timeLimitSeconds,
  }) async {
    final data = await _api.post('/admin/live-arena/schedule', data: {
      'startsAt': startsAt.toIso8601String(),
      if (titleFa != null && titleFa.trim().isNotEmpty) 'titleFa': titleFa.trim(),
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      'minRankNo': minRankNo,
      'questionCount': questionCount,
      'timeLimitSeconds': timeLimitSeconds,
    });
    return (data as Map)['eventId']?.toString() ?? '';
  }

  Future<void> cancel(String eventId) {
    return _api.delete('/admin/live-arena/$eventId');
  }
}
