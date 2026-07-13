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
  });

  @override
  List<Object?> get props => [studentDisplayName, overallProgressPercent];
}
