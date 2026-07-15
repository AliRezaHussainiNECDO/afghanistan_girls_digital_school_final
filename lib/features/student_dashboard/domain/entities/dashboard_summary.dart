import 'package:equatable/equatable.dart';

/// خلاصهٔ داشبورد دانش‌آموز — تجمیع چند سیگنال برای نمایش سریع در خانه
/// (بخش ۵.۵ توصیه‌ها + بخش ۶ پیشرفت + بخش ۷ امتحان + بخش ۱۲ سمینار).
class DashboardSummary extends Equatable {
  final String studentDisplayName;
  final double overallProgressPercent;
  final String currentLessonTitle;
  final String currentSubjectNameFa;
  final String? upcomingExamTitle;
  final DateTime? upcomingExamDate;
  final String? upcomingSeminarTitle;
  final DateTime? upcomingSeminarDate;
  final List<String> recommendedTopics; // طبق بخش ۵.۵ — نقاط ضعف فعال

  /// امتیاز فعالیت (Gamification) — طبق `backend/src/lib/progress.ts`
  /// `getPointsSummary`؛ همین سه فیلد در داشبورد والدین هم نمایش داده
  /// می‌شود تا منطق امتیازدهی در همه‌جا یکسان باشد.
  final int pointsTotal;
  final int pointsLevel;
  final String pointsLevelTitleFa;

  const DashboardSummary({
    required this.studentDisplayName,
    required this.overallProgressPercent,
    required this.currentLessonTitle,
    required this.currentSubjectNameFa,
    this.upcomingExamTitle,
    this.upcomingExamDate,
    this.upcomingSeminarTitle,
    this.upcomingSeminarDate,
    this.recommendedTopics = const [],
    this.pointsTotal = 0,
    this.pointsLevel = 1,
    this.pointsLevelTitleFa = 'نوآموز',
  });

  @override
  List<Object?> get props => [studentDisplayName, overallProgressPercent];
}
