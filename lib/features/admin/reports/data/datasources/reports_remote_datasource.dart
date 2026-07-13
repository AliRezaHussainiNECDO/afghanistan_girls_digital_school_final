import '../../../../../core/network/api_client.dart';
import '../../domain/entities/report_row.dart';

/// قرارداد مشترک DataSource گزارش‌ها — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class ReportsDataSource {
  Future<List<ReportRow>> getSummaryReport();
}

/// پیاده‌سازی واقعی — `GET /api/v1/admin/reports/summary` (بخش ۱۵.۳).
/// همهٔ اعداد از دادهٔ واقعی سرور محاسبه می‌شوند.
class ReportsRemoteDataSource implements ReportsDataSource {
  final ApiClient _api;
  ReportsRemoteDataSource(this._api);

  @override
  Future<List<ReportRow>> getSummaryReport() async {
    final data = await _api.get('/admin/reports/summary');
    final rows = (data['rows'] as List? ?? []);
    return rows
        .map((r) => ReportRow(
              label: r['label'] as String? ?? '',
              value: r['value'] as String? ?? '',
            ))
        .toList();
  }
}
