import '../../domain/entities/system_health.dart';
import 'system_health_remote_datasource.dart' show SystemHealthDataSource;

class SystemHealthMockDataSource implements SystemHealthDataSource {
  @override
  Future<SystemHealth> checkHealth() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    return SystemHealth(
      timestamp: now,
      overallStatus: SystemOverallStatus.operational,
      checks: const [
        ServiceCheck(id: 'api', status: ServiceCheckStatus.ok, latencyMs: 40),
        ServiceCheck(id: 'database', status: ServiceCheckStatus.ok, latencyMs: 18),
        ServiceCheck(id: 'storage', status: ServiceCheckStatus.ok, latencyMs: 52),
        ServiceCheck(id: 'auth', status: ServiceCheckStatus.ok),
        ServiceCheck(
          id: 'aiTeacher',
          status: ServiceCheckStatus.warning,
          detailFa: 'حالت نمایشی — بدون بک‌اند واقعی (Mock)',
          detailEn: 'Demo mode — no live backend (Mock)',
        ),
      ],
    );
  }
}
