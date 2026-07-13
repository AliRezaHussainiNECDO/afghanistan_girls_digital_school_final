import '../../domain/entities/attendance_entities.dart';
import 'attendance_remote_datasource.dart' show AttendanceDataSource;

class AttendanceMockDataSource implements AttendanceDataSource {
  @override
  Future<AttendanceSummary> getSummary(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final today = DateTime.now();
    final statuses = [
      AttendanceStatus.present,
      AttendanceStatus.present,
      AttendanceStatus.partial,
      AttendanceStatus.present,
      AttendanceStatus.absent,
      AttendanceStatus.present,
      AttendanceStatus.excused,
    ];
    final days = List.generate(
      14,
      (i) => AttendanceDay(
        date: today.subtract(Duration(days: 13 - i)),
        status: statuses[i % statuses.length],
      ),
    );
    return AttendanceSummary(ratePercent: 91.2, recentDays: days);
  }
}
