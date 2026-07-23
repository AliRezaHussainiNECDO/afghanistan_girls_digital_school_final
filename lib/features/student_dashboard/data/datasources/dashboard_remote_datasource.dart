import '../../../../core/network/api_client.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../models/dashboard_summary_model.dart';

/// قرارداد مشترک DataSource خلاصهٔ داشبورد — Mock و Remote هر دو آن را
/// پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class DashboardDataSource {
  Future<DashboardSummaryModel> getSummary(String studentId);
}

/// پیاده‌سازی واقعی — `GET /api/v1/students/me/dashboard-summary`.
class DashboardRemoteDataSource implements DashboardDataSource {
  final ApiClient _api;
  DashboardRemoteDataSource(this._api);

  @override
  Future<DashboardSummaryModel> getSummary(String studentId) async {
    final data = await _api.get('/students/me/dashboard-summary');
    final m = Map<String, dynamic>.from(data as Map);
    return DashboardSummaryModel(
      studentDisplayName: m['studentDisplayName'] as String? ?? '',
      overallProgressPercent: (m['overallProgressPercent'] as num?)?.toDouble() ?? 0,
      currentLessonTitle: m['currentLessonTitle'] as String? ?? '',
      currentSubjectNameFa: m['currentSubjectNameFa'] as String? ?? '',
      continueLearning: (m['continueLearning'] as List? ?? [])
          .map((e) {
            final j = Map<String, dynamic>.from(e as Map);
            return ContinueLearningItem(
              subjectId: j['subjectId'] as String? ?? '',
              subjectNameFa: j['subjectNameFa'] as String? ?? '',
              lessonTitle: j['lessonTitle'] as String? ?? '',
              progressPercent: (j['progressPercent'] as num?)?.toDouble() ?? 0,
            );
          })
          .toList(),
      upcomingExamTitle: m['upcomingExamTitle'] as String?,
      upcomingExamDate: DateTime.tryParse(m['upcomingExamDate'] as String? ?? ''),
      // رفع اشکال «فقط یک سمینار»: سرور اکنون فهرست کامل سمینارهای در
      // انتظار را می‌فرستد (`upcomingSeminars`)، نه یک عنوان/تاریخ تکی.
      upcomingSeminars: (m['upcomingSeminars'] as List? ?? [])
          .map((e) {
            final j = Map<String, dynamic>.from(e as Map);
            return UpcomingSeminarPreview(
              title: j['title'] as String? ?? '',
              scheduledStart:
                  DateTime.tryParse(j['scheduledStart'] as String? ?? '') ?? DateTime.now(),
            );
          })
          .toList(),
      recommendedTopics:
          (m['recommendedTopics'] as List? ?? []).map((e) => e.toString()).toList(),
      pointsTotal: (m['pointsTotal'] as num?)?.toInt() ?? 0,
      pointsLevel: (m['pointsLevel'] as num?)?.toInt() ?? 1,
      pointsLevelTitleFa: m['pointsLevelTitleFa'] as String? ?? 'نوآموز',
      pointsNextLevelAt: (m['pointsNextLevelAt'] as num?)?.toInt(),
      pointsNextLevelTitleFa: m['pointsNextLevelTitleFa'] as String?,
      pointsProgressToNextPercent: (m['pointsProgressToNextPercent'] as num?)?.toDouble() ?? 0,
      certificatesCount: (m['certificatesCount'] as num?)?.toInt() ?? 0,
    );
  }
}
