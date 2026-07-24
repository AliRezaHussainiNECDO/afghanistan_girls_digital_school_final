/// DataSource «زندهٔ» مدیریت شاگردان — بازنویسی‌شده تا مدیر **معلومات حقیقی**
/// ببیند، نه لیست تولیدی/تصادفی نسخهٔ قبل. همه‌چیز از منابع واحد حقیقتِ
/// خود برنامه خوانده می‌شود (همان اصل «هرچه شاگرد می‌بیند، مدیر همان را
/// می‌بیند» که Parent Dashboard از قبل رعایت می‌کرد):
///
///  • هویت/ثبت‌نام: `StudentDirectory` (Demo + هر شاگردی که با Invite Code راجستر شود)
///  • صنف فعلی و پیشرفت مضامین: `ProgressionStore` (منبع داشبورد شاگرد/والد)
///  • نمرات: `AcademyStore` (آخرین Submission هر مضمون — همان منطق والد)
///  • حاضری: `AttendanceMockDataSource` (همان منبع صفحهٔ حاضری خود شاگرد)
///  • پیوند والدین: `GuardianLinkMockStore` (فقط Mock)  • گواهی‌نامه‌ها: `CertificatesLocalDataSource`
///
/// در فاز ۲ این کلاس با `StudentManagementRemoteDataSourceImpl` (Dio →
/// `GET /admin/users?role=student`) جایگزین می‌شود؛ Interface ثابت می‌ماند.

library;
import '../../../../../../core/mock/guardian_link_mock_store.dart';
import '../../../../../../core/student/student_directory.dart';
import '../../../../../../shared_models/subject.dart';
import '../../../../../academy/data/academy_store.dart';
import '../../../../../academy/domain/academy_entities.dart';
import '../../../../../attendance/data/datasources/attendance_mock_datasource.dart';
import '../../../../../attendance/domain/entities/attendance_entities.dart' as att;
import '../../../../../certificates/data/datasources/certificates_local_datasource.dart';
import '../../../../../progression/data/progression_store.dart';
import '../../../domain/entities/student_entities.dart';
import '../../models/student_models.dart';
import 'student_management_remote_datasource.dart';

class StudentManagementMockDataSource
    implements StudentManagementRemoteDataSource {
  static const int _lessonsPerSubject = 24;

  final String localeCode;
  StudentManagementMockDataSource({this.localeCode = 'fa'});

  static const Map<String, Map<String, String>> _i18n = {
    'fa': {
      'studentNotFound': 'شاگرد یافت نشد',
      'unknownProvince': 'نامشخص',
      'unknownParent': 'والد/سرپرست',
      'attendanceBelowThreshold': 'نرخ حاضری {rate}٪ — زیر آستانهٔ ۷۵٪ (بخش ۶.۲ سند)',
      'lowSubjectScore': 'نمرهٔ {subject} پایین است ({score}٪) — نیاز به تمرین بیشتر',
      'noExamsYet': 'هنوز هیچ امتحان/کوییزی ثبت نشده است',
      'decliningTrend': 'روند نمرات در امتحان‌های اخیر نزولی است',
      'strongPerformance': 'عملکرد قوی در {subject} (نمرهٔ {score}٪)',
      'regularAttendance': 'حاضری منظم ({rate}٪)',
      'activeParticipation': '{count} ارزیابی تکمیل‌شده — مشارکت فعال',
      'practiceRecommended': 'جلسات تمرینی {subject} با استاد هوش مصنوعی توصیه می‌شود',
      'notifyParentsAttendance': 'اطلاع‌رسانی به والدین دربارهٔ حاضری (بخش ۱۳ب.۴ سند)',
      'continueCurrentPath': 'ادامهٔ مسیر فعلی؛ محتوای تکمیلی قابل فعال‌سازی است',
      'bestSubjectNote': 'آخرین نمره {score}٪ — آمادهٔ محتوای سطح بالاتر.',
      'weakSubjectNote': 'آخرین نمره {score}٪ — تکرار و تمرین بیشتر لازم است.',
    },
    'en': {
      'studentNotFound': 'Student not found',
      'unknownProvince': 'Unknown',
      'unknownParent': 'Parent/guardian',
      'attendanceBelowThreshold': 'Attendance rate {rate}% — below the 75% threshold (doc section 6.2)',
      'lowSubjectScore': '{subject} score is low ({score}%) — needs more practice',
      'noExamsYet': 'No exams/quizzes recorded yet',
      'decliningTrend': 'Scores have been declining in recent exams',
      'strongPerformance': 'Strong performance in {subject} (score {score}%)',
      'regularAttendance': 'Regular attendance ({rate}%)',
      'activeParticipation': '{count} assessments completed — active participation',
      'practiceRecommended': 'Practice sessions in {subject} with the AI Teacher are recommended',
      'notifyParentsAttendance': 'Notify parents about attendance (doc section 13b.4)',
      'continueCurrentPath': 'Continue the current path; supplementary content can be enabled',
      'bestSubjectNote': 'Latest score {score}% — ready for higher-level content.',
      'weakSubjectNote': 'Latest score {score}% — needs review and more practice.',
    },
    'ps': {
      'studentNotFound': 'زده کوونکی ونه موندل شو',
      'unknownProvince': 'ناڅرګند',
      'unknownParent': 'مور/پلار یا کفیل',
      'attendanceBelowThreshold': 'د حاضرۍ کچه {rate}٪ — د ۷۵٪ حد نه ښکته (د سند ۶.۲ برخه)',
      'lowSubjectScore': 'د {subject} نمره ټیټه ده ({score}٪) — ډیر تمرین ته اړتیا لري',
      'noExamsYet': 'تر اوسه هیڅ ازموینه/کوییز نه دی ثبت شوی',
      'decliningTrend': 'په وروستیو ازموینو کې د نمرو رجحان ښکته روان دی',
      'strongPerformance': 'په {subject} کې پیاوړی فعالیت (نمره {score}٪)',
      'regularAttendance': 'منظمه حاضري ({rate}٪)',
      'activeParticipation': '{count} بشپړ شوي ارزونې — فعاله ګډون',
      'practiceRecommended': 'د {subject} د تمرین ناستې د AI ښوونکي سره وړاندیز کیږي',
      'notifyParentsAttendance': 'مور/پلار ته د حاضرۍ په اړه خبرتیا (د سند ۱۳ب.۴ برخه)',
      'continueCurrentPath': 'اوسنی لار دوام ورکړئ؛ بشپړوونکې منځپانګه فعالولی شئ',
      'bestSubjectNote': 'وروستۍ نمره {score}٪ — د لوړې کچې منځپانګې لپاره چمتو ده.',
      'weakSubjectNote': 'وروستۍ نمره {score}٪ — بیاکتنه او ډیر تمرین ته اړتیا لري.',
    },
    'fr': {
      'studentNotFound': 'Élève introuvable',
      'unknownProvince': 'Inconnue',
      'unknownParent': 'Parent/tuteur',
      'attendanceBelowThreshold': 'Taux de présence {rate} % — sous le seuil de 75 % (doc, section 6.2)',
      'lowSubjectScore': 'Note en {subject} faible ({score} %) — besoin de plus de pratique',
      'noExamsYet': 'Aucun examen/quiz enregistré pour l’instant',
      'decliningTrend': 'Les notes sont en baisse lors des derniers examens',
      'strongPerformance': 'Bonne performance en {subject} (note {score} %)',
      'regularAttendance': 'Présence régulière ({rate} %)',
      'activeParticipation': '{count} évaluations complétées — participation active',
      'practiceRecommended': 'Des séances de pratique en {subject} avec le professeur IA sont recommandées',
      'notifyParentsAttendance': 'Informer les parents de la présence (doc, section 13b.4)',
      'continueCurrentPath': 'Poursuivre le parcours actuel ; du contenu complémentaire peut être activé',
      'bestSubjectNote': 'Dernière note {score} % — prêt pour un contenu de niveau supérieur.',
      'weakSubjectNote': 'Dernière note {score} % — révision et pratique supplémentaire nécessaires.',
    },
  };

  String _t(String key, [Map<String, String>? params]) {
    var s = _i18n[localeCode]?[key] ?? _i18n['fa']![key]!;
    params?.forEach((k, v) {
      s = s.replaceAll('{$k}', v);
    });
    return s;
  }

  AccountStatus _accountStatus(StudentAccountStatus s) => switch (s) {
        StudentAccountStatus.active => AccountStatus.active,
        StudentAccountStatus.suspended => AccountStatus.suspended,
        StudentAccountStatus.deleted => AccountStatus.deleted,
      };

  /// آخرین نمرهٔ هر مضمون از Submission های واقعی (کلید = نام فارسی مضمون،
  /// همان الگوی ParentMockDataSource).
  Map<String, Submission> _latestBySubject(List<Submission> subs) {
    final map = <String, Submission>{};
    for (final s in subs) {
      final existing = map[s.subject];
      if (existing == null || s.submittedAt.isAfter(existing.submittedAt)) {
        map[s.subject] = s;
      }
    }
    return map;
  }

  double _gradeAverage(Map<String, Submission> latest) {
    if (latest.isEmpty) return 0;
    final sum = latest.values.fold<double>(0, (a, s) => a + s.scorePercent);
    return sum / latest.length;
  }

  /// قاعدهٔ سادهٔ ریسک (تا فاز ۲ که Early Warning Score واقعی سرور بیاید —
  /// بخش ۸.۳ سند): حاضری/میانگین پایین ⇒ در معرض خطر.
  RiskLevel _risk(double attendanceRate, double avg, bool hasScores) {
    if (attendanceRate < 60 || (hasScores && avg < 40)) return RiskLevel.high;
    if (attendanceRate < 75 || (hasScores && avg < 55)) return RiskLevel.medium;
    return RiskLevel.none;
  }

  Future<StudentSummaryModel> _summaryFor(StudentRecord r) async {
    final progress = ProgressionStore.instance.progressFor(r.id);
    final subs = AcademyStore().getSubmissions(studentId: r.id);
    final latest = _latestBySubject(subs);
    // میانگین نمرات از Submission های واقعی؛ اگر هنوز امتحانی ثبت نشده،
    // به درصد پیشرفت واقعی صنف (ProgressionStore — همان عددی که داشبورد
    // شاگرد/والد نشان می‌دهد) به‌عنوان شاخص تکیه می‌کنیم، نه صفرِ گمراه‌کننده.
    final hasScores = latest.isNotEmpty;
    final avg = hasScores ? _gradeAverage(latest) : progress.overallCompletion;
    final attendance = await AttendanceMockDataSource().getSummary(r.id);
    return StudentSummaryModel(
      id: r.id,
      fullName: r.fullName,
      grade: progress.currentGrade,
      province: r.province.isEmpty ? _t('unknownProvince') : r.province,
      status: _accountStatus(r.status),
      riskLevel: _risk(attendance.ratePercent, avg, hasScores),
      gradeAverage: avg,
      attendanceRate: attendance.ratePercent,
      lastActiveAt: subs.isNotEmpty ? subs.first.submittedAt : null,
    );
  }

  @override
  Future<PagedStudentsModel> fetchStudents(StudentListFilter filter) async {
    final records = StudentDirectory.instance.all.where((r) {
      final q = filter.query?.trim() ?? '';
      if (q.isNotEmpty &&
          !r.fullName.contains(q) &&
          !r.email.contains(q) &&
          !r.province.contains(q)) {
        return false;
      }
      return true;
    }).toList();

    final summaries = await Future.wait(records.map(_summaryFor));
    final list = summaries.where((s) {
      if (filter.grade != null && s.grade != filter.grade) return false;
      if (filter.province != null && s.province != filter.province) return false;
      if (filter.status != null && s.status != filter.status) return false;
      if (filter.atRiskOnly && s.riskLevel == RiskLevel.none) return false;
      return true;
    }).toList();

    return PagedStudentsModel(
        items: list, total: list.length, page: 1, pageSize: 50);
  }

  @override
  Future<StudentDetailModel> fetchStudentDetail(String studentId) async {
    final r = StudentDirectory.instance.byId(studentId);
    if (r == null) {
      throw StateError(_t('studentNotFound'));
    }
    final summary = await _summaryFor(r);
    final progress = ProgressionStore.instance.progressFor(r.id);
    final subs = AcademyStore().getSubmissions(studentId: r.id);
    final latest = _latestBySubject(subs);

    // ── پیشرفت واقعی هر ۱۰ مضمون (همان ProgressionStore داشبورد شاگرد) ──
    final subjects = mockSubjects.map((s) {
      final pct = (progress.completion[s.id] ?? 0).clamp(0, 100).toDouble();
      final subjectSubs =
          subs.where((x) => x.subject == s.nameFa).toList();
      final quizAvg = subjectSubs.isEmpty
          ? null
          : subjectSubs.fold<double>(0, (a, x) => a + x.scorePercent) /
              subjectSubs.length;
      return SubjectProgressModel(
        subjectId: s.id,
        subjectName: s.nameFa,
        status: pct >= 100
            ? SubjectStatus.completed
            : (pct > 0 ? SubjectStatus.inProgress : SubjectStatus.locked),
        progressPercent: pct,
        finalScore: latest[s.nameFa]?.scorePercent,
        quizAverage: quizAvg,
        examAverage: latest[s.nameFa]?.scorePercent,
        completedLessons: (pct / 100 * _lessonsPerSubject).round(),
        totalLessons: _lessonsPerSubject,
      );
    }).toList();

    // ── حاضری: همان منبع صفحهٔ حاضری خود شاگرد ──
    final a = await AttendanceMockDataSource().getSummary(r.id);
    bool isPresent(att.AttendanceDay d) =>
        d.status == att.AttendanceStatus.present ||
        d.status == att.AttendanceStatus.partial;
    final attendance = AttendanceSummaryModel(
      presentDays: a.recentDays.where(isPresent).length,
      absentDays: a.recentDays
          .where((d) => d.status == att.AttendanceStatus.absent)
          .length,
      rate: a.ratePercent,
      belowThreshold: a.ratePercent < 75,
      last30Days: a.recentDays
          .map((d) => AttendanceDay(date: d.date, present: isPresent(d)))
          .toList(),
    );

    // ── پیوندهای والدین در حالت Mock (GuardianLinkMockStore — بخش ۱۳ب) ──
    final links = GuardianLinkMockStore.instance.linksForStudent(r.id);
    final parentLinks = links
        .map((l) => ParentLink(
              linkId: '${l.parentId}:${l.studentId}',
              parentName:
                  l.parentName.isEmpty ? _t('unknownParent') : l.parentName,
              linkStatus: switch (l.status) {
                GuardianLinkStatus.approved => 'approved',
                GuardianLinkStatus.pendingStudentApproval =>
                  'pending_student_approval',
                GuardianLinkStatus.rejected => 'rejected',
              },
            ))
        .toList();

    // ── گواهی‌نامه‌های واقعاً صادرشده برای همین شاگرد ──
    final certs = await CertificatesLocalDataSource().getForStudent(r.id);

    // ── رتبه در صنف: بین همهٔ شاگردان واقعی همان صنف (بخش ۸.۱) ──
    final peers = StudentDirectory.instance.all
        .where((x) => x.status != StudentAccountStatus.deleted)
        .toList();
    final peerAvgs = <String, double>{};
    var classSize = 0;
    for (final p in peers) {
      final pg = ProgressionStore.instance.progressFor(p.id);
      if (pg.currentGrade != progress.currentGrade) continue;
      classSize++;
      peerAvgs[p.id] =
          _gradeAverage(_latestBySubject(AcademyStore().getSubmissions(studentId: p.id)));
    }
    final myAvg = peerAvgs[r.id] ?? 0;
    final classRank =
        1 + peerAvgs.values.where((v) => v > myAvg).length;

    return StudentDetailModel(
      summary: summary,
      email: r.email,
      phone: r.phone.isEmpty ? '—' : r.phone,
      birthDate: r.birthDate ?? DateTime(2010, 1, 1),
      registeredAt: r.registeredAt,
      subjects: subjects,
      attendance: attendance,
      parentLinks: parentLinks,
      certificatesCount: certs.length,
      // ردیابی per-student گفتگوهای AI در فاز ۱ وجود ندارد؛ مقدار واقعی از
      // جدول ai_conversations در فاز ۲ می‌آید (بخش ۱۷.۳ سند) — صفرِ صادقانه.
      aiConversationsCount: 0,
      examsTaken: subs.length,
      classRank: classRank,
      classSize: classSize == 0 ? 1 : classSize,
      allSubjectsComplete: progress.allSubjectsComplete,
      examPassed: progress.examPassed,
      examBestScore: progress.examTaken ? progress.examScore : null,
      canPromote: progress.canPromote,
    );
  }

  @override
  Future<AiTeacherReportModel> fetchAiReport(String studentId) async {
    final r = StudentDirectory.instance.byId(studentId);
    if (r == null) throw StateError(_t('studentNotFound'));
    final summary = await _summaryFor(r);
    final subs = AcademyStore().getSubmissions(studentId: r.id);
    final latest = _latestBySubject(subs);

    // روند واقعی: مقایسهٔ میانگین نیمهٔ قدیمی‌تر و نیمهٔ جدیدتر نمرات.
    Trend trend = Trend.stable;
    if (subs.length >= 4) {
      final sorted = [...subs]
        ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
      final half = sorted.length ~/ 2;
      double avgOf(List<Submission> l) =>
          l.fold<double>(0, (a, s) => a + s.scorePercent) / l.length;
      final older = avgOf(sorted.take(half).toList());
      final newer = avgOf(sorted.skip(half).toList());
      trend = newer - older > 5
          ? Trend.improving
          : (older - newer > 5 ? Trend.declining : Trend.stable);
    }

    // قوی‌ترین/ضعیف‌ترین مضمون از نمرات واقعی.
    String? bestSubject;
    String? weakSubject;
    double best = -1, weak = 101;
    latest.forEach((name, s) {
      if (s.scorePercent > best) {
        best = s.scorePercent;
        bestSubject = name;
      }
      if (s.scorePercent < weak) {
        weak = s.scorePercent;
        weakSubject = name;
      }
    });

    final concerns = <String>[
      if (summary.attendanceRate < 75)
        _t('attendanceBelowThreshold', {'rate': summary.attendanceRate.toStringAsFixed(0)}),
      if (weakSubject != null && weak < 55)
        _t('lowSubjectScore', {'subject': weakSubject!, 'score': weak.toStringAsFixed(0)}),
      if (subs.isEmpty) _t('noExamsYet'),
      if (trend == Trend.declining) _t('decliningTrend'),
    ];

    return AiTeacherReportModel(
      generatedAt: DateTime.now(),
      overallProgress: summary.gradeAverage,
      trend: trend,
      stressLevel: switch (summary.riskLevel) {
        RiskLevel.high => StressLevel.high,
        RiskLevel.medium => StressLevel.medium,
        _ => StressLevel.low,
      },
      engagementScore: (summary.attendanceRate * 0.6 + (subs.isEmpty ? 0 : 40))
          .clamp(0, 100)
          .toDouble(),
      strengths: [
        if (bestSubject != null && best >= 70)
          _t('strongPerformance', {'subject': bestSubject!, 'score': best.toStringAsFixed(0)}),
        if (summary.attendanceRate >= 75)
          _t('regularAttendance', {'rate': summary.attendanceRate.toStringAsFixed(0)}),
        if (subs.length >= 3) _t('activeParticipation', {'count': '${subs.length}'}),
      ],
      concerns: concerns,
      recommendations: [
        if (weakSubject != null && weak < 55)
          _t('practiceRecommended', {'subject': weakSubject!}),
        if (summary.attendanceRate < 75)
          _t('notifyParentsAttendance'),
        if (concerns.isEmpty) _t('continueCurrentPath'),
      ],
      subjectNotes: [
        if (bestSubject != null)
          SubjectNote(
              subjectName: bestSubject!,
              note: _t('bestSubjectNote', {'score': best.toStringAsFixed(0)})),
        if (weakSubject != null && weakSubject != bestSubject)
          SubjectNote(
              subjectName: weakSubject!,
              note: _t('weakSubjectNote', {'score': weak.toStringAsFixed(0)})),
      ],
    );
  }

  @override
  Future<void> patchStatus(
      String studentId, AccountStatus status, String reason) async {
    StudentDirectory.instance.setStatus(
      studentId,
      switch (status) {
        AccountStatus.suspended => StudentAccountStatus.suspended,
        AccountStatus.deleted => StudentAccountStatus.deleted,
        _ => StudentAccountStatus.active,
      },
    );
  }

  @override
  Future<void> softDelete(String studentId, String reason) =>
      patchStatus(studentId, AccountStatus.deleted, reason);

  @override
  Future<void> sendPasswordResetLink(String studentId) =>
      Future.delayed(const Duration(milliseconds: 300));

  @override
  Future<int> promoteGrade(String studentId) async {
    ProgressionStore.instance.promote(studentId);
    return ProgressionStore.instance.progressFor(studentId).currentGrade;
  }

  @override
  Future<int> demoteGrade(String studentId) async {
    ProgressionStore.instance.demote(studentId);
    return ProgressionStore.instance.progressFor(studentId).currentGrade;
  }
}
