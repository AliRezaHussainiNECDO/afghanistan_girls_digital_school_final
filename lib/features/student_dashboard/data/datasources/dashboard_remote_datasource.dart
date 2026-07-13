import '../../../../core/network/api_client.dart';
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
      upcomingExamTitle: m['upcomingExamTitle'] as String?,
      upcomingExamDate: DateTime.tryParse(m['upcomingExamDate'] as String? ?? ''),
      upcomingSeminarTitle: m['upcomingSeminarTitle'] as String?,
      upcomingSeminarDate: DateTime.tryParse(m['upcomingSeminarDate'] as String? ?? ''),
      recommendedTopics:
          (m['recommendedTopics'] as List? ?? []).map((e) => e.toString()).toList(),
    );
  }
}
