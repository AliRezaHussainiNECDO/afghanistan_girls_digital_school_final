import '../../domain/entities/dashboard_summary.dart';

class DashboardSummaryModel extends DashboardSummary {
  const DashboardSummaryModel({
    required super.studentDisplayName,
    required super.overallProgressPercent,
    required super.currentLessonTitle,
    required super.currentSubjectNameFa,
    super.continueLearning,
    super.upcomingExamTitle,
    super.upcomingExamDate,
    super.upcomingSeminars,
    super.recommendedTopics,
    super.pointsTotal,
    super.pointsLevel,
    super.pointsLevelTitleFa,
    super.pointsNextLevelAt,
    super.pointsNextLevelTitleFa,
    super.pointsProgressToNextPercent,
    super.certificatesCount,
  });
}
