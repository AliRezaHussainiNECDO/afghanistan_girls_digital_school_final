import '../../../../core/student/guardian_link_store.dart';
import '../../../../shared_models/subject.dart';
import '../../../academy/data/academy_store.dart';
import '../../../academy/domain/academy_entities.dart';
import '../../../attendance/data/datasources/attendance_mock_datasource.dart';
import '../../../certificates/data/datasources/certificates_local_datasource.dart';
import '../../../progression/data/progression_store.dart';
import '../../domain/entities/parent_entities.dart';
import 'parent_remote_datasource.dart' show ParentDataSource;

/// منبع دادهٔ داشبورد والدین — از منابع واحد حقیقتِ خود شاگرد می‌خواند تا
/// «هر چه شاگرد می‌بیند، والد همان را ببیند» (اصل بخش ۱۳ب.۳):
///
/// * فرزندان و پیوندها ← `GuardianLinkStore` (کد دعوت، چند فرزند).
/// * صنف فعلی و پیشرفت مضامین ← `ProgressionStore` (همان منبع داشبورد شاگرد؛
///   پس از ارتقای صنف، خودکار صنف جدید نمایش می‌یابد).
/// * نمرهٔ هر مضمون ← آخرین Submission در `AcademyStore` (همان منطق امتحانات).
/// * گواهی‌نامه‌ها ← `CertificatesLocalDataSource` (صادرشده توسط مدیر برای
///   همین شاگرد — نه لیست ثابت).
/// * دستاوردها ← نشان‌های محاسبه‌شده از همین داده‌های واقعی.
/// * حاضری ← همان منبع صفحهٔ حاضری شاگرد.
class ParentMockDataSource implements ParentDataSource {
  GuardianLinkStore get _links => GuardianLinkStore.instance;

  @override
  Future<List<LinkedChild>> getLinkedChildren(String parentId) async {
    await Future.delayed(const Duration(milliseconds: 250));
    return _links
        .childrenOf(parentId)
        .map((l) => LinkedChild(studentId: l.studentId, displayName: l.studentName))
        .toList();
  }

  @override
  Future<ChildSummary> getChildSummary(String studentId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final link = _links.linkForStudent(studentId);
    final displayName = link?.studentName ?? 'فرزند';

    // ── پیشرفت صنف/مضامین: همان ProgressionStore داشبورد شاگرد ──
    final progress = ProgressionStore.instance
        .progressFor(studentId, fallbackGrade: link?.gradeAtLink ?? 7);
    final grade = progress.currentGrade;

    // ── آخرین نمرهٔ امتحان هر مضمون در صنف فعلی (از AcademyStore) ──
    final submissions =
        AcademyStore().getSubmissions(studentId: studentId, gradeId: grade);
    final latestBySubject = <String, Submission>{};
    for (final s in submissions) {
      final existing = latestBySubject[s.subject];
      if (existing == null || s.submittedAt.isAfter(existing.submittedAt)) {
        latestBySubject[s.subject] = s;
      }
    }

    // ── وضعیت هر ۱۰ مضمون (بخش ۶.۱): تکمیل / در حال پیشرفت / شروع‌نشده ──
    final subjects = mockSubjects.map((s) {
      final completion = (progress.completion[s.id] ?? 0).clamp(0, 100);
      final status = completion >= 100
          ? 'completed'
          : (completion > 0 ? 'in_progress' : 'locked');
      return ChildSubjectSummary(
        subjectNameFa: s.nameFa,
        statusLabel: status,
        finalScore: latestBySubject[s.nameFa]?.scorePercent,
      );
    }).toList();

    // ── گواهی‌نامه‌های واقعی صادرشده برای همین فرزند ──
    final certs = await CertificatesLocalDataSource().getForStudent(studentId);
    final certificateTitles = certs
        .map((c) =>
            'گواهی‌نامهٔ ختم صنف ${c.grade} — سال ${c.yearLabel}${c.honor.isEmpty ? '' : ' (${c.honor})'}')
        .toList();

    // ── دستاوردها: نشان‌های محاسبه‌شده از دادهٔ واقعی همین فرزند ──
    final allSubs = AcademyStore().getSubmissions(studentId: studentId);
    final completedCount =
        mockSubjects.where((s) => (progress.completion[s.id] ?? 0) >= 100).length;
    final achievements = <String>[
      if (allSubs.isNotEmpty) 'اولین امتحان',
      if (allSubs.any((s) => s.scorePercent >= 80)) 'نمرهٔ عالی (۸۰٪+)',
      if (completedCount >= 3) 'تکمیل $completedCount مضمون',
      if (progress.allSubjectsComplete) 'تکمیل همهٔ مضامین صنف',
      if (grade > progress.enrolledGrade) 'ارتقا به صنف بالاتر',
      if (certs.isNotEmpty) 'دارندهٔ گواهی‌نامه',
    ];

    // ── حاضری: همان منبع صفحهٔ حاضری شاگرد ──
    final attendance = await AttendanceMockDataSource().getSummary(studentId);

    return ChildSummary(
      studentId: studentId,
      displayName: displayName,
      gradeNumber: grade,
      gradeCompletionPercent: progress.overallCompletion,
      attendanceRatePercent: attendance.ratePercent,
      subjects: subjects,
      achievements: achievements,
      certificates: certificateTitles,
      // سمینارها صفحهٔ اختصاصی خود را دارند (ParentSeminarsScreen)؛ اینجا
      // فقط عنوان‌های نمونهٔ پیش رو نمایش داده می‌شود (بخش ۱۳ب.۳: فقط
      // عنوان/تاریخ، نه محتوای سمینار).
      upcomingSeminarTitles: const ['مهارت‌های مطالعهٔ مؤثر'],
    );
  }

  /// اعتبارسنجی و مصرف کد دعوت. خطاهای خوانا (کد نامعتبر، منقضی، فرزند
  /// تکراری، درخواست تکراری) از `GuardianLinkStore.redeemCode` پرتاب و در
  /// Repository به `ValidationFailure` تبدیل می‌شوند. خروجی = نام فرزند.
  ///
  /// اصلاح ۲.۴ (بخش ۱۳ب.۲ سند): پیوند با وضعیت `pending_student_approval`
  /// ساخته می‌شود و تا تأیید خود شاگرد در لیست فرزندان ظاهر نمی‌شود.
  @override
  Future<String> submitInviteCode(String parentId, String code, {String parentName = ''}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final link = _links.redeemCode(parentId: parentId, parentName: parentName, rawCode: code);
    return link.studentName;
  }
}
