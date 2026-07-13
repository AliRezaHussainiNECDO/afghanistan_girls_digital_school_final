import '../../domain/entities/admin_stats.dart';
import 'admin_dashboard_remote_datasource.dart' show AdminDashboardDataSource;

class AdminDashboardMockDataSource implements AdminDashboardDataSource {
  @override
  Future<AdminStats> getStats() async {
    await Future.delayed(const Duration(milliseconds: 350));
    return const AdminStats(
      totalStudents: 1284,
      activeToday: 412,
      atRiskCount: 37,
      avgScorePercent: 71.8,
      gradeDistribution: {7: 260, 8: 245, 9: 230, 10: 210, 11: 180, 12: 159},
    );
  }
}
