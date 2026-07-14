import '../../../../../core/network/api_client.dart';
import '../../domain/entities/system_health.dart';

abstract class SystemHealthDataSource {
  Future<SystemHealth> checkHealth();
}

class SystemHealthRemoteDataSource implements SystemHealthDataSource {
  final ApiClient _api;
  SystemHealthRemoteDataSource(this._api);

  @override
  Future<SystemHealth> checkHealth() async {
    final data = await _api.get('/admin/system-health');
    final m = Map<String, dynamic>.from(data as Map);
    final checksRaw = (m['checks'] as List?) ?? const [];
    final checks = checksRaw.map((raw) {
      final c = Map<String, dynamic>.from(raw as Map);
      return ServiceCheck(
        id: c['id']?.toString() ?? 'unknown',
        status: _parseStatus(c['status']?.toString()),
        latencyMs: (c['latencyMs'] as num?)?.toInt(),
        detailFa: c['detail_fa']?.toString(),
        detailEn: c['detail_en']?.toString(),
      );
    }).toList();
    return SystemHealth(
      timestamp: DateTime.tryParse(m['timestamp']?.toString() ?? '') ?? DateTime.now(),
      overallStatus: _parseOverall(m['overallStatus']?.toString()),
      checks: checks,
    );
  }

  ServiceCheckStatus _parseStatus(String? v) {
    switch (v) {
      case 'ok':
        return ServiceCheckStatus.ok;
      case 'warning':
        return ServiceCheckStatus.warning;
      case 'error':
      default:
        return ServiceCheckStatus.error;
    }
  }

  SystemOverallStatus _parseOverall(String? v) {
    switch (v) {
      case 'operational':
        return SystemOverallStatus.operational;
      case 'degraded':
        return SystemOverallStatus.degraded;
      case 'down':
      default:
        return SystemOverallStatus.down;
    }
  }
}
