import '../models/dashboard_summary_model.dart';
import 'dashboard_remote_datasource.dart' show DashboardDataSource;

class DashboardMockDataSource implements DashboardDataSource {
  @override
  Future<DashboardSummaryModel> getSummary(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 350));
    return DashboardSummaryModel(
      studentDisplayName: 'مریم',
      overallProgressPercent: 68.4,
      currentLessonTitle: 'معادلات درجهٔ دوم',
      currentSubjectNameFa: 'ریاضی',
      upcomingExamTitle: 'امتحان ماهانهٔ فزیک',
      upcomingExamDate: DateTime.now().add(const Duration(days: 3)),
      upcomingSeminarTitle: 'مهارت‌های مطالعهٔ مؤثر',
      upcomingSeminarDate: DateTime.now().add(const Duration(days: 6)),
      recommendedTopics: const ['معادلات درجهٔ دوم', 'دستور زبان انگلیسی — Past Tense'],
      pointsTotal: 240,
      pointsLevel: 3,
      pointsLevelTitleFa: 'کوشا',
    );
  }
}
