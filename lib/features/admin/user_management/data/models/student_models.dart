/// DTO ها — نگاشت JSON ↔ Entity (بخش ۲۴.۱، data/models).

library;
import '../../domain/entities/student_entities.dart';

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
        id: json['id'] as String,
        fullName: json['full_name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        grade: json['current_grade'] as int,
        province: json['province'] as String,
        status: _statusFrom(json['status'] as String),
        riskLevel: _riskFrom(json['risk_level'] as String?),
        gradeAverage: (json['grade_average'] as num?)?.toDouble() ?? 0,
        attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
        lastActiveAt: json['last_active_at'] != null
            ? DateTime.parse(json['last_active_at'] as String)
            : null,
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
        items: (json['items'] as List)
            .map((e) => StudentSummaryModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pageSize: json['page_size'] as int,
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
        subjectId: json['subject_id'] as String,
        subjectName: json['subject_name'] as String,
        status: _subjectStatusFrom(json['status'] as String?),
        progressPercent: (json['progress_percent'] as num).toDouble(),
        finalScore: (json['final_score'] as num?)?.toDouble(),
        quizAverage: (json['quiz_average'] as num?)?.toDouble(),
        examAverage: (json['exam_average'] as num?)?.toDouble(),
        completedLessons: json['completed_lessons'] as int,
        totalLessons: json['total_lessons'] as int,
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
        presentDays: json['present_days'] as int,
        absentDays: json['absent_days'] as int,
        rate: (json['rate'] as num).toDouble(),
        belowThreshold: json['below_threshold'] as bool? ?? false,
        last30Days: (json['last_30_days'] as List? ?? [])
            .map((e) => AttendanceDay(
                  date: _lenientDate(e['date'] as String?),
                  present: e['present'] as bool? ?? false,
                ))
            .toList(),
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
        summary:
            StudentSummaryModel.fromJson(json['summary'] as Map<String, dynamic>),
        email: json['email'] as String,
        phone: json['phone'] as String,
        birthDate: _lenientDate(json['birth_date'] as String?),
        registeredAt: _lenientDate(json['registered_at'] as String?,
            fallback: DateTime.now()),
        subjects: (json['subjects'] as List? ?? [])
            .map((e) =>
                SubjectProgressModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        attendance: AttendanceSummaryModel.fromJson(
            json['attendance'] as Map<String, dynamic>),
        parentLinks: (json['parent_links'] as List? ?? [])
            .map((e) => ParentLink(
                  linkId: e['link_id'] as String,
                  parentName: e['parent_name'] as String,
                  linkStatus: e['status'] as String,
                ))
            .toList(),
        certificatesCount: json['certificates_count'] as int? ?? 0,
        aiConversationsCount: json['ai_conversations_count'] as int? ?? 0,
        examsTaken: json['exams_taken'] as int? ?? 0,
        classRank: json['class_rank'] as int? ?? 0,
        classSize: json['class_size'] as int? ?? 0,
        allSubjectsComplete: json['all_subjects_complete'] as bool? ?? false,
        examPassed: json['exam_passed'] as bool? ?? false,
        examBestScore: (json['exam_best_score'] as num?)?.toDouble(),
        canPromote: json['can_promote'] as bool? ?? false,
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
        generatedAt: DateTime.parse(json['generated_at'] as String),
        overallProgress: (json['overall_progress'] as num).toDouble(),
        trend: _trendFrom(json['trend'] as String?),
        stressLevel: _stressFrom(json['stress_level'] as String?),
        engagementScore: (json['engagement_score'] as num).toDouble(),
        strengths: List<String>.from(json['strengths'] as List? ?? []),
        concerns: List<String>.from(json['concerns'] as List? ?? []),
        recommendations:
            List<String>.from(json['recommendations'] as List? ?? []),
        subjectNotes: (json['subject_notes'] as List? ?? [])
            .map((e) => SubjectNote(
                  subjectName: e['subject_name'] as String,
                  note: e['note'] as String,
                ))
            .toList(),
      );
}
