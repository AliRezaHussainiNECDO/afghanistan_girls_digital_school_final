import '../../domain/entities/dashboard_summary.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.studentDisplayName,
    required super.overallProgressPercent,
    required super.currentLessonTitle,
    required super.currentSubjectNameFa,
    super.upcomingExamTitle,
    super.upcomingExamDate,
    super.upcomingSeminarTitle,
    super.upcomingSeminarDate,
    super.recommendedTopics,
  });
}
