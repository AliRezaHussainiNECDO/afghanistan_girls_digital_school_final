/// DTO ها — نگاشت JSON ↔ Entity (بخش ۲۴.۱، data/models).

library;
import '../../domain/entities/student_entities.dart';

// رفع اشکال: قبلاً همهٔ فیلدهای JSON مستقیم Cast می‌شدند (`as String`،
// `as int`، `as Map<String, dynamic>`) — یعنی هر مقدار null/گمشده/نوعِ
// نامنتظر از سرور (رکورد قدیمی، ستون خالی، ...) بلافاصله با یک TypeError
// خام کل صفحهٔ ادمین را کرش می‌کرد، به‌جای نمایش یک مقدار پیش‌فرض بی‌خطر
// (همان الگویی که در audit_logs/error_logs از قبل رعایت شده بود).
// این کمک‌تابع‌ها همان الگو را اینجا هم اعمال می‌کنند.
String _s(dynamic v, [String fallback = '']) => v == null ? fallback : v.toString();
String? _sOrNull(dynamic v) => v?.toString();
int _i(dynamic v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? fallback;
double _d(dynamic v, [double fallback = 0]) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? fallback;
double? _dOrNull(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
bool _b(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;
Map<String, dynamic> _map(dynamic v) =>
    v is Map<String, dynamic> ? v : (v is Map ? Map<String, dynamic>.from(v) : const {});
List _list(dynamic v) => v is List ? v : const [];

AccountStatus _statusFrom(String s) => switch (s) {
      'active' => AccountStatus.active,
      'suspended' => AccountStatus.suspended,
      'pending_verification' => AccountStatus.pendingVerification,
      'deleted' => AccountStatus.deleted,
      _ => AccountStatus.active,
    };

String accountStatusToApi(AccountStatus s) => switch (s) {
      AccountStatus.active => 'active',
      AccountStatus.suspended => 'suspended',
      AccountStatus.pendingVerification => 'pending_verification',
      AccountStatus.deleted => 'deleted',
    };

/// پارس مقاوم تاریخ — برخی مقادیر قدیمی date_of_birth با اسلش ('/') به‌جای
/// خط‌تیره ثبت شده‌اند (فرم ثبت‌نام قبلاً فرمت را اجبار نمی‌کرد) که باعث
/// کرش DateTime.parse سخت‌گیرانه و نمایش اشتباه «خطای سرور» می‌شد.
DateTime _lenientDate(String? raw, {DateTime? fallback}) {
  if (raw == null || raw.isEmpty) return fallback ?? DateTime(2010, 1, 1);
  final normalized = raw.replaceAll('/', '-');
  return DateTime.tryParse(normalized) ?? (fallback ?? DateTime(2010, 1, 1));
}

RiskLevel _riskFrom(String? s) => switch (s) {
      'high' => RiskLevel.high,
      'medium' => RiskLevel.medium,
      'low' => RiskLevel.low,
      _ => RiskLevel.none,
    };

StressLevel _stressFrom(String? s) => switch (s) {
      'high' => StressLevel.high,
      'medium' => StressLevel.medium,
      _ => StressLevel.low,
    };

Trend _trendFrom(String? s) => switch (s) {
      'improving' => Trend.improving,
      'declining' => Trend.declining,
      _ => Trend.stable,
    };

SubjectStatus _subjectStatusFrom(String? s) => switch (s) {
      'completed' => SubjectStatus.completed,
      'failed' => SubjectStatus.failed,
      'locked' => SubjectStatus.locked,
      _ => SubjectStatus.inProgress,
    };

class StudentSummaryModel extends StudentSummary {
  const StudentSummaryModel({
    required super.id,
    required super.fullName,
    super.avatarUrl,
    required super.grade,
    required super.province,
    required super.status,
    required super.riskLevel,
    required super.gradeAverage,
    required super.attendanceRate,
    super.lastActiveAt,
  });

  factory StudentSummaryModel.fromJson(Map<String, dynamic> json) =>
      StudentSummaryModel(
        id: _s(json['id']),
        fullName: _s(json['full_name']),
        avatarUrl: _sOrNull(json['avatar_url']),
        grade: _i(json['current_grade']),
        province: _s(json['province']),
        status: _statusFrom(_s(json['status'])),
        riskLevel: _riskFrom(_sOrNull(json['risk_level'])),
        gradeAverage: _d(json['grade_average']),
        attendanceRate: _d(json['attendance_rate']),
        lastActiveAt: DateTime.tryParse(_s(json['last_active_at'])),
      );
}

class PagedStudentsModel extends PagedStudents {
  const PagedStudentsModel({
    required super.items,
    required super.total,
    required super.page,
    required super.pageSize,
  });

  factory PagedStudentsModel.fromJson(Map<String, dynamic> json) =>
      PagedStudentsModel(
        items: _list(json['items']).map((e) => StudentSummaryModel.fromJson(_map(e))).toList(),
        total: _i(json['total']),
        page: _i(json['page']),
        pageSize: _i(json['page_size']),
      );
}

class SubjectProgressModel extends SubjectProgress {
  const SubjectProgressModel({
    required super.subjectId,
    required super.subjectName,
    required super.status,
    required super.progressPercent,
    super.finalScore,
    super.quizAverage,
    super.examAverage,
    required super.completedLessons,
    required super.totalLessons,
  });

  factory SubjectProgressModel.fromJson(Map<String, dynamic> json) =>
      SubjectProgressModel(
        subjectId: _s(json['subject_id']),
        subjectName: _s(json['subject_name']),
        status: _subjectStatusFrom(_sOrNull(json['status'])),
        progressPercent: _d(json['progress_percent']),
        finalScore: _dOrNull(json['final_score']),
        quizAverage: _dOrNull(json['quiz_average']),
        examAverage: _dOrNull(json['exam_average']),
        completedLessons: _i(json['completed_lessons']),
        totalLessons: _i(json['total_lessons']),
      );
}

class AttendanceSummaryModel extends AttendanceSummary {
  const AttendanceSummaryModel({
    required super.presentDays,
    required super.absentDays,
    required super.rate,
    required super.belowThreshold,
    required super.last30Days,
  });

  factory AttendanceSummaryModel.fromJson(Map<String, dynamic> json) =>
      AttendanceSummaryModel(
        presentDays: _i(json['present_days']),
        absentDays: _i(json['absent_days']),
        rate: _d(json['rate']),
        belowThreshold: _b(json['below_threshold']),
        last30Days: _list(json['last_30_days']).map((e) {
          final day = _map(e);
          return AttendanceDay(
            date: _lenientDate(_sOrNull(day['date'])),
            present: _b(day['present']),
          );
        }).toList(),
      );
}

class StudentDetailModel extends StudentDetail {
  const StudentDetailModel({
    required super.summary,
    required super.email,
    required super.phone,
    required super.birthDate,
    required super.registeredAt,
    required super.subjects,
    required super.attendance,
    required super.parentLinks,
    required super.certificatesCount,
    required super.aiConversationsCount,
    required super.examsTaken,
    required super.classRank,
    required super.classSize,
    super.allSubjectsComplete,
    super.examPassed,
    super.examBestScore,
    super.canPromote,
  });

  factory StudentDetailModel.fromJson(Map<String, dynamic> json) =>
      StudentDetailModel(
        summary: StudentSummaryModel.fromJson(_map(json['summary'])),
        email: _s(json['email']),
        phone: _s(json['phone']),
        birthDate: _lenientDate(_sOrNull(json['birth_date'])),
        registeredAt: _lenientDate(_sOrNull(json['registered_at']), fallback: DateTime.now()),
        subjects: _list(json['subjects']).map((e) => SubjectProgressModel.fromJson(_map(e))).toList(),
        attendance: AttendanceSummaryModel.fromJson(_map(json['attendance'])),
        parentLinks: _list(json['parent_links']).map((e) {
          final link = _map(e);
          return ParentLink(
            linkId: _s(link['link_id']),
            parentName: _s(link['parent_name']),
            linkStatus: _s(link['status']),
          );
        }).toList(),
        certificatesCount: _i(json['certificates_count']),
        aiConversationsCount: _i(json['ai_conversations_count']),
        examsTaken: _i(json['exams_taken']),
        classRank: _i(json['class_rank']),
        classSize: _i(json['class_size']),
        allSubjectsComplete: _b(json['all_subjects_complete']),
        examPassed: _b(json['exam_passed']),
        examBestScore: _dOrNull(json['exam_best_score']),
        canPromote: _b(json['can_promote']),
      );
}

class AiTeacherReportModel extends AiTeacherReport {
  const AiTeacherReportModel({
    required super.generatedAt,
    required super.overallProgress,
    required super.trend,
    required super.stressLevel,
    required super.engagementScore,
    required super.strengths,
    required super.concerns,
    required super.recommendations,
    required super.subjectNotes,
  });

  factory AiTeacherReportModel.fromJson(Map<String, dynamic> json) =>
      AiTeacherReportModel(
        generatedAt: DateTime.tryParse(_s(json['generated_at'])) ?? DateTime.now(),
        overallProgress: _d(json['overall_progress']),
        trend: _trendFrom(_sOrNull(json['trend'])),
        stressLevel: _stressFrom(_sOrNull(json['stress_level'])),
        engagementScore: _d(json['engagement_score']),
        strengths: _list(json['strengths']).map((e) => _s(e)).toList(),
        concerns: _list(json['concerns']).map((e) => _s(e)).toList(),
        recommendations: _list(json['recommendations']).map((e) => _s(e)).toList(),
        subjectNotes: _list(json['subject_notes']).map((e) {
          final note = _map(e);
          return SubjectNote(
            subjectName: _s(note['subject_name']),
            note: _s(note['note']),
          );
        }).toList(),
      );
}
