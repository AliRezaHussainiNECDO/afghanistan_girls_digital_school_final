import '../../../../core/network/api_client.dart';
import '../../domain/entities/attendance_entities.dart';

/// قرارداد مشترک DataSource حاضری — Mock و Remote هر دو آن را پیاده می‌کنند
/// تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class AttendanceDataSource {
  Future<AttendanceSummary> getSummary(String studentId);
}

/// پیاده‌سازی واقعی — `GET /api/v1/attendance/{id}/summary` (بخش ۹ سند).
/// حاضری را سرور از فعالیت واقعی (بازدید درس/تلاش امتحان) محاسبه می‌کند.
class AttendanceRemoteDataSource implements AttendanceDataSource {
  final ApiClient _api;
  AttendanceRemoteDataSource(this._api);

  @override
  Future<AttendanceSummary> getSummary(String studentId) async {
    final data = await _api.get('/attendance/$studentId/summary');
    final days = (data['recentDays'] as List? ?? []).map((e) {
      return AttendanceDay(
        date: DateTime.tryParse(e['date'] as String? ?? '') ?? DateTime.now(),
        status: _statusFrom(e['status'] as String?),
      );
    }).toList();
    return AttendanceSummary(
      ratePercent: (data['ratePercent'] as num?)?.toDouble() ?? 0,
      recentDays: days,
    );
  }

  AttendanceStatus _statusFrom(String? s) => switch (s) {
        'present' => AttendanceStatus.present,
        'partial' => AttendanceStatus.partial,
        'excused' => AttendanceStatus.excused,
        _ => AttendanceStatus.absent,
      };
}
