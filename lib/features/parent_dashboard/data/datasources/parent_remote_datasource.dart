import '../../../../core/network/api_client.dart';
import '../../domain/entities/parent_entities.dart';

/// قرارداد مشترک DataSource داشبورد والد — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class ParentDataSource {
  Future<List<LinkedChild>> getLinkedChildren(String parentId);
  Future<ChildSummary> getChildSummary(String studentId);
  Future<String> submitInviteCode(String parentId, String code, {String parentName});
}

/// پیاده‌سازی واقعی — روتر parents زیر `/api/v1` (بخش ۱۳ب سند).
/// کارنامه، حاضری و پیشرفت فرزند به‌صورت زنده از سرور خوانده می‌شوند.
class ParentRemoteDataSource implements ParentDataSource {
  final ApiClient _api;
  ParentRemoteDataSource(this._api);

  @override
  Future<List<LinkedChild>> getLinkedChildren(String parentId) async {
    final data = await _api.get('/parents/me/children');
    final list = (data['children'] as List? ?? []);
    return list
        .map((e) => LinkedChild(
              studentId: e['studentId'] as String,
              displayName: e['displayName'] as String? ?? 'فرزند',
            ))
        .toList();
  }

  @override
  Future<ChildSummary> getChildSummary(String studentId) async {
    final data = await _api.get('/parents/me/children/$studentId/summary');
    final m = Map<String, dynamic>.from(data as Map);
    final subjects = (m['subjects'] as List? ?? [])
        .map((s) => ChildSubjectSummary(
              subjectNameFa: s['subjectNameFa'] as String? ?? '',
              statusLabel: s['statusLabel'] as String? ?? 'locked',
              finalScore: (s['finalScore'] as num?)?.toDouble(),
              progressPercent: (s['progressPercent'] as num?)?.toDouble(),
            ))
        .toList();
    return ChildSummary(
      studentId: m['studentId'] as String? ?? studentId,
      displayName: m['displayName'] as String? ?? 'فرزند',
      gradeNumber: (m['gradeNumber'] as num?)?.toInt() ?? 7,
      gradeCompletionPercent: (m['gradeCompletionPercent'] as num?)?.toDouble() ?? 0,
      attendanceRatePercent: (m['attendanceRatePercent'] as num?)?.toDouble() ?? 0,
      subjects: subjects,
      achievements: (m['achievements'] as List? ?? []).map((x) => x.toString()).toList(),
      certificates: (m['certificates'] as List? ?? []).map((x) => x.toString()).toList(),
      upcomingSeminarTitles:
          (m['upcomingSeminarTitles'] as List? ?? []).map((x) => x.toString()).toList(),
      pointsTotal: (m['pointsTotal'] as num?)?.toInt() ?? 0,
      pointsLevel: (m['pointsLevel'] as num?)?.toInt() ?? 1,
      pointsLevelTitleFa: m['pointsLevelTitleFa'] as String? ?? 'نوآموز',
    );
  }

  @override
  Future<String> submitInviteCode(String parentId, String code, {String parentName = ''}) async {
    final data = await _api.post('/parents/link-requests', data: {'code': code});
    return (data['studentName'] as String?) ?? 'فرزند';
  }
}
