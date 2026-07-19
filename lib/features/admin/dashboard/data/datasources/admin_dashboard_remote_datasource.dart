import '../../../../../core/network/api_client.dart';
import '../../domain/entities/admin_stats.dart';

/// قرارداد مشترک DataSource آمار داشبورد مدیر — Mock و Remote هر دو آن را
/// پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class AdminDashboardDataSource {
  Future<AdminStats> getStats();

  /// «نبض زندهٔ مکتب» — `GET /admin/dashboard/live` (ضربان حضور، migration 0032).
  Future<AdminLiveStats> getLiveStats();
}

/// پیاده‌سازی واقعی — `GET /api/v1/admin/dashboard/stats` (بخش ۱۵.۱).
class AdminDashboardRemoteDataSource implements AdminDashboardDataSource {
  final ApiClient _api;
  AdminDashboardRemoteDataSource(this._api);

  @override
  Future<AdminStats> getStats() async {
    final data = await _api.get('/admin/dashboard/stats');
    final m = Map<String, dynamic>.from(data as Map);
    final distRaw = (m['gradeDistribution'] as Map?) ?? {};
    final dist = <int, int>{};
    distRaw.forEach((k, v) {
      final g = int.tryParse(k.toString());
      if (g != null) dist[g] = (v as num).toInt();
    });
    return AdminStats(
      totalStudents: (m['totalStudents'] as num?)?.toInt() ?? 0,
      activeToday: (m['activeToday'] as num?)?.toInt() ?? 0,
      atRiskCount: (m['atRiskCount'] as num?)?.toInt() ?? 0,
      avgScorePercent: (m['avgScorePercent'] as num?)?.toDouble() ?? 0,
      gradeDistribution: dist,
    );
  }

  @override
  Future<AdminLiveStats> getLiveStats() async {
    final data = await _api.get('/admin/dashboard/live');
    final m = Map<String, dynamic>.from(data as Map);
    final roles = Map<String, dynamic>.from((m['roles'] as Map?) ?? {});
    final online = Map<String, dynamic>.from((m['online'] as Map?) ?? {});
    final today = Map<String, dynamic>.from((m['today'] as Map?) ?? {});
    final pending = Map<String, dynamic>.from((m['pending'] as Map?) ?? {});
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    return AdminLiveStats(
      students: n(roles['students']),
      parents: n(roles['parents']),
      instructors: n(roles['instructors']),
      onlineTotal: n(online['total']),
      onlineStudents: n(online['students']),
      onlineParents: n(online['parents']),
      onlineInstructors: n(online['instructors']),
      recentOnline: ((online['recent'] as List?) ?? [])
          .map((u) => OnlineUser(
                id: u['id'] as String? ?? '',
                name: u['name'] as String? ?? '',
                role: u['role'] as String? ?? 'student',
                gradeNumber: (u['gradeNumber'] as num?)?.toInt(),
                avatarUrl: _absoluteUrl(u['avatarUrl'] as String?),
                lastSeenAt: DateTime.tryParse(
                        (u['lastSeenAt'] as String? ?? '').replaceFirst(' ', 'T')) ??
                    DateTime.now(),
              ))
          .toList(),
      lessonsViewedToday: n(today['lessonsViewed']),
      examAttemptsToday: n(today['examAttempts']),
      chatMessagesToday: n(today['chatMessages']),
      homeworksSubmittedToday: n(today['homeworksSubmitted']),
      newUsersToday: n(today['newUsers']),
      pendingChatReviews: n(pending['chatReviews']),
      pendingSafetyFlags: n(pending['safetyFlags']),
    );
  }

  String? _absoluteUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$kApiBaseUrl$url';
  }
}
