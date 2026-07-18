import '../../domain/entities/report_row.dart';
import 'reports_remote_datasource.dart' show ReportsDataSource;

class ReportsMockDataSource implements ReportsDataSource {
  final String localeCode;
  const ReportsMockDataSource({this.localeCode = 'fa'});

  Map<String, String> get _strings => switch (localeCode) {
        'en' => const {
            'overallAttendanceRate': 'Overall attendance rate',
            'classCompletionRate': 'Class completion rate',
            'academicDropoutRate': 'Academic dropout rate',
            'certificatesIssued': 'Certificates issued',
            'studentsAtRisk': 'Students at risk',
          },
        'ps' => const {
            'overallAttendanceRate': 'ټولیز د حاضرۍ کچه',
            'classCompletionRate': 'د ټولګي بشپړونې کچه',
            'academicDropoutRate': 'د تعلیمي پرېښودنې کچه',
            'certificatesIssued': 'صادر شوي سندونه',
            'studentsAtRisk': 'خطر سره مخ زده کوونکي',
          },
        'fr' => const {
            'overallAttendanceRate': 'Taux de présence global',
            'classCompletionRate': 'Taux d’achèvement de classe',
            'academicDropoutRate': 'Taux de décrochage scolaire',
            'certificatesIssued': 'Certificats délivrés',
            'studentsAtRisk': 'Élèves à risque',
          },
        _ => const {
            'overallAttendanceRate': 'نرخ حاضری کلی',
            'classCompletionRate': 'نرخ تکمیل صنف',
            'academicDropoutRate': 'نرخ افت تحصیلی',
            'certificatesIssued': 'تعداد گواهی‌نامه‌های صادرشده',
            'studentsAtRisk': 'دانش‌آموزان در معرض خطر',
          },
      };

  @override
  Future<List<ReportRow>> getSummaryReport() async {
    await Future.delayed(const Duration(milliseconds: 300));
    final s = _strings;
    return [
      ReportRow(label: s['overallAttendanceRate']!, value: '89.4%'),
      ReportRow(label: s['classCompletionRate']!, value: '64.2%'),
      ReportRow(label: s['academicDropoutRate']!, value: '4.1%'),
      ReportRow(label: s['certificatesIssued']!, value: '312'),
      ReportRow(label: s['studentsAtRisk']!, value: '37'),
    ];
  }
}
