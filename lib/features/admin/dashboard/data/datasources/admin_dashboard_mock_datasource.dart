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

  @override
  Future<AdminLiveStats> getLiveStats() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final now = DateTime.now();
    return AdminLiveStats(
      students: 1284,
      parents: 342,
      instructors: 27,
      onlineTotal: 63,
      onlineStudents: 54,
      onlineParents: 7,
      onlineInstructors: 2,
      recentOnline: [
        OnlineUser(id: 'u1', name: 'مریم احمدی', role: 'student', gradeNumber: 7, lastSeenAt: now),
        OnlineUser(id: 'u2', name: 'فاطمه رضایی', role: 'student', gradeNumber: 8, lastSeenAt: now.subtract(const Duration(minutes: 1))),
        OnlineUser(id: 'u3', name: 'حمیده نوری', role: 'parent', lastSeenAt: now.subtract(const Duration(minutes: 4))),
        OnlineUser(id: 'u4', name: 'استاد کریمی', role: 'seminar_instructor', lastSeenAt: now.subtract(const Duration(minutes: 9))),
      ],
      lessonsViewedToday: 231,
      examAttemptsToday: 58,
      chatMessagesToday: 412,
      homeworksSubmittedToday: 74,
      newUsersToday: 12,
      pendingChatReviews: 3,
      pendingSafetyFlags: 1,
    );
  }
}
