import 'package:equatable/equatable.dart';

/// یک کاربرِ همین حالا آنلاین/اخیر — برای فهرست زندهٔ داشبورد مدیر
/// (GET /admin/dashboard/live — ضربان حضور، migration 0032).
class OnlineUser extends Equatable {
  final String id;
  final String name;
  final String role; // student|parent|seminar_instructor
  final int? gradeNumber;
  final String? avatarUrl;
  final DateTime lastSeenAt;

  const OnlineUser({
    required this.id,
    required this.name,
    required this.role,
    this.gradeNumber,
    this.avatarUrl,
    required this.lastSeenAt,
  });

  /// آنلاین یعنی فعالیت در ۲ دقیقهٔ اخیر (هماهنگ با سرور).
  bool get isOnline => DateTime.now().difference(lastSeenAt).inMinutes < 2;

  @override
  List<Object?> get props => [id, lastSeenAt];
}

/// «نبض زندهٔ مکتب» — همهٔ اعداد زندهٔ صفحهٔ اول مدیر در یک پاسخ:
/// شمار کاربران هر ۳ نقش، آنلاین‌های همین حالا (به تفکیک نقش + فهرست)،
/// فعالیت امروز و موارد نیازمند اقدام.
class AdminLiveStats extends Equatable {
  final int students;
  final int parents;
  final int instructors;

  final int onlineTotal;
  final int onlineStudents;
  final int onlineParents;
  final int onlineInstructors;
  final List<OnlineUser> recentOnline;

  final int lessonsViewedToday;
  final int examAttemptsToday;
  final int chatMessagesToday;
  final int homeworksSubmittedToday;
  final int newUsersToday;

  final int pendingChatReviews;
  final int pendingSafetyFlags;

  const AdminLiveStats({
    required this.students,
    required this.parents,
    required this.instructors,
    required this.onlineTotal,
    required this.onlineStudents,
    required this.onlineParents,
    required this.onlineInstructors,
    required this.recentOnline,
    required this.lessonsViewedToday,
    required this.examAttemptsToday,
    required this.chatMessagesToday,
    required this.homeworksSubmittedToday,
    required this.newUsersToday,
    required this.pendingChatReviews,
    required this.pendingSafetyFlags,
  });

  int get totalUsers => students + parents + instructors;

  @override
  List<Object?> get props => [
        students,
        parents,
        instructors,
        onlineTotal,
        recentOnline,
        lessonsViewedToday,
        examAttemptsToday,
        chatMessagesToday,
        pendingChatReviews,
        pendingSafetyFlags,
      ];
}

/// طبق بخش ۱۵.۱ سند (KPI ها).
class AdminStats extends Equatable {
  final int totalStudents;
  final int activeToday;
  final int atRiskCount;
  final double avgScorePercent;
  final Map<int, int> gradeDistribution; // grade -> count

  const AdminStats({
    required this.totalStudents,
    required this.activeToday,
    required this.atRiskCount,
    required this.avgScorePercent,
    required this.gradeDistribution,
  });

  @override
  List<Object?> get props => [totalStudents, activeToday];
}
