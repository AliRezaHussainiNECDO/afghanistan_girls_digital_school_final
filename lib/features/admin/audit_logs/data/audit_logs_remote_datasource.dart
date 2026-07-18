import '../../../../core/network/api_client.dart';
import '../domain/entities/audit_log_entry.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DataSource لاگ بازبینی — `GET /api/v1/admin/audit-logs` (فقط Super Admin).
///
/// صفحه‌بندی Cursor-محور: پارامتر `before` (ISO datetime آخرین رکورد صفحهٔ
/// قبل) صفحهٔ بعدی را می‌آورد — هماهنگ با Endpoint سرور (routes/admin.ts).
/// ═══════════════════════════════════════════════════════════════════════════
class AuditLogsRemoteDataSource {
  final ApiClient _api;
  const AuditLogsRemoteDataSource(this._api);

  Future<List<AuditLogEntry>> fetch({
    String? actionType,
    String? priority,
    String? before,
    int limit = 100,
  }) async {
    final data = await _api.get('/admin/audit-logs', queryParameters: {
      if (actionType != null && actionType.isNotEmpty) 'actionType': actionType,
      if (priority != null && priority.isNotEmpty) 'priority': priority,
      if (before != null && before.isNotEmpty) 'before': before,
      'limit': limit,
    });
    final logs = (data is Map ? data['logs'] : null);
    if (logs is! List) return const [];
    // پارس تک‌به‌تک با مرز خطا: یک رکورد بدشکل کل لیست را نمی‌اندازد.
    final out = <AuditLogEntry>[];
    for (final item in logs) {
      if (item is! Map) continue;
      try {
        out.add(AuditLogEntry.fromJson(item.map((k, v) => MapEntry(k.toString(), v))));
      } catch (_) {
        // رکورد خراب — نادیده گرفته می‌شود؛ اپ هرگز نباید اینجا کرش کند.
      }
    }
    return out;
  }
}
