import '../../domain/entities/report_row.dart';
import 'reports_remote_datasource.dart' show ReportsDataSource;

class ReportsMockDataSource implements ReportsDataSource {
  @override
  Future<List<ReportRow>> getSummaryReport() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [
      ReportRow(label: 'نرخ حاضری کلی', value: '89.4%'),
      ReportRow(label: 'نرخ تکمیل صنف', value: '64.2%'),
      ReportRow(label: 'نرخ افت تحصیلی', value: '4.1%'),
      ReportRow(label: 'تعداد گواهی‌نامه‌های صادرشده', value: '312'),
      ReportRow(label: 'دانش‌آموزان در معرض خطر', value: '37'),
    ];
  }
}
