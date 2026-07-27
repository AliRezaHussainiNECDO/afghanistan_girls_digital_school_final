import '../../../../core/network/api_client.dart';
import '../domain/entities/error_log_entry.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DataSource «گزارش خطاهای برنامه» — `GET/PATCH/DELETE /api/v1/admin/error-logs`
/// (نیاز به مجوز 'manage_error_logs'، رجوع کن backend/src/routes/errorLogs.ts).
/// ═══════════════════════════════════════════════════════════════════════════
class ErrorLogsRemoteDataSource {
  final ApiClient _api;
  const ErrorLogsRemoteDataSource(this._api);

  Future<({List<ErrorLogEntry> items, int total, int page, int pageSize})> fetch({
    String? status,
    String? severity,
    String? category,
    String? from,
    String? to,
    String? query,
    int page = 1,
    int pageSize = 25,
  }) async {
    final data = await _api.get('/admin/error-logs', queryParameters: {
      if (status != null && status.isNotEmpty) 'status': status,
      if (severity != null && severity.isNotEmpty) 'severity': severity,
      if (category != null && category.isNotEmpty) 'category': category,
      if (from != null && from.isNotEmpty) 'from': from,
      if (to != null && to.isNotEmpty) 'to': to,
      if (query != null && query.isNotEmpty) 'q': query,
      'page': page,
      'pageSize': pageSize,
    });

    final rawItems = (data is Map ? data['items'] : null);
    final items = <ErrorLogEntry>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map) continue;
        try {
          items.add(ErrorLogEntry.fromJson(item.map((k, v) => MapEntry(k.toString(), v))));
        } catch (_) {
          // رکورد بدشکل — نادیده گرفته می‌شود، اپ هرگز نباید اینجا کرش کند.
        }
      }
    }
    return (
      items: items,
      total: (data is Map ? data['total'] as int? : null) ?? items.length,
      page: (data is Map ? data['page'] as int? : null) ?? page,
      pageSize: (data is Map ? data['pageSize'] as int? : null) ?? pageSize,
    );
  }

  Future<ErrorLogEntry> fetchDetail(String id) async {
    final data = await _api.get('/admin/error-logs/$id');
    return ErrorLogEntry.fromJson((data as Map).map((k, v) => MapEntry(k.toString(), v)));
  }

  Future<void> updateStatus(String id, {required ErrorLogStatus status, String? resolutionNotes}) {
    return _api.patch('/admin/error-logs/$id', data: {
      'status': ErrorLogEntry.statusToApi(status),
      if (resolutionNotes != null && resolutionNotes.isNotEmpty) 'resolutionNotes': resolutionNotes,
    });
  }

  Future<void> delete(String id) {
    return _api.delete('/admin/error-logs/$id');
  }
}
