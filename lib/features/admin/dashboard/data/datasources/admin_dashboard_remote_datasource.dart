import '../../../../../core/network/api_client.dart';
import '../../domain/entities/admin_stats.dart';

/// قرارداد مشترک DataSource آمار داشبورد مدیر — Mock و Remote هر دو آن را
/// پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class AdminDashboardDataSource {
  Future<AdminStats> getStats();
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
}
