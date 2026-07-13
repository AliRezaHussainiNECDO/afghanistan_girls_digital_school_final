/// Entities خالص (Pure Dart — بدون وابستگی به Flutter) — بخش ۲۴.۱ سند SPEC.
///
/// اصل حاکم بخش ۴: تمام مقادیر این Entity ها (میانگین، نرخ حاضری، وضعیت خطر،
/// گزارش AI و غیره) توسط Backend محاسبه شده‌اند؛ کلاینت فقط نمایش می‌دهد.
library;

enum AccountStatus { active, suspended, pendingVerification, deleted }

enum RiskLevel { none, low, medium, high }

enum StressLevel { low, medium, high }

enum Trend { improving, stable, declining }

enum SubjectStatus { locked, inProgress, completed, failed }

/// ردیف لیست شاگردان (GET /api/v1/admin/users?role=student)
class StudentSummary {
  final String id;
  final String fullName;
  final String? avatarUrl;
  final int grade; // 7..12
  final String province;
  final AccountStatus status;
  final RiskLevel riskLevel; // at_risk_flag (بخش ۸.۳/۹.۴)
  final double gradeAverage; // محاسبه‌شده در Backend
  final double attendanceRate; // ۰..۱۰۰
  final DateTime? lastActiveAt;

  const StudentSummary({
    required this.id,
    required this.fullName,
    this.avatarUrl,
    required this.grade,
    required this.province,
    required this.status,
    required this.riskLevel,
    required this.gradeAverage,
    required this.attendanceRate,
    this.lastActiveAt,
  });
}

class PagedStudents {
  final List<StudentSummary> items;
  final int total;
  final int page;
  final int pageSize;
  const PagedStudents({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });
  bool get hasMore => page * pageSize < total;
}

/// فیلترهای لیست — فقط به‌عنوان Query String به سرور ارسال می‌شوند.
class StudentListFilter {
  final String? query;
  final int? grade;
  final String? province;
  final AccountStatus? status;
  final bool atRiskOnly;
  final int page;

  const StudentListFilter({
    this.query,
    this.grade,
    this.province,
    this.status,
    this.atRiskOnly = false,
    this.page = 1,
  });

  StudentListFilter copyWith({
    String? query,
    int? grade,
    String? province,
    AccountStatus? status,
    bool? atRiskOnly,
    int? page,
    bool clearGrade = false,
    bool clearProvince = false,
    bool clearStatus = false,
  }) =>
      StudentListFilter(
        query: query ?? this.query,
        grade: clearGrade ? null : (grade ?? this.grade),
        province: clearProvince ? null : (province ?? this.province),
        status: clearStatus ? null : (status ?? this.status),
        atRiskOnly: atRiskOnly ?? this.atRiskOnly,
        page: page ?? this.page,
      );
}

/// پیشرفت یک مضمون — خروجی آمادهٔ نمایش از Backend (الگوی BFF، بخش ۴.۴).
class SubjectProgress {
  final String subjectId;
  final String subjectName;
  final SubjectStatus status;
  final double progressPercent; // ۰..۱۰۰
  final double? finalScore; // Final_Subject_Score محاسبه‌شده در سرور
  final double? quizAverage;
  final double? examAverage;
  final int completedLessons;
  final int totalLessons;

  const SubjectProgress({
    required this.subjectId,
    required this.subjectName,
    required this.status,
    required this.progressPercent,
    this.finalScore,
    this.quizAverage,
    this.examAverage,
    required this.completedLessons,
    required this.totalLessons,
  });
}

class AttendanceDay {
  final DateTime date;
  final bool present;
  const AttendanceDay({required this.date, required this.present});
}

class AttendanceSummary {
  final int presentDays;
  final int absentDays;
  final double rate; // ۰..۱۰۰ — آستانهٔ ۷۵٪ در grading_policies سرور
  final bool belowThreshold; // تصمیم سرور، نه کلاینت (بخش ۴.۱)
  final List<AttendanceDay> last30Days;

  const AttendanceSummary({
    required this.presentDays,
    required this.absentDays,
    required this.rate,
    required this.belowThreshold,
    required this.last30Days,
  });
}

class ParentLink {
  final String linkId;
  final String parentName;
  final String linkStatus; // pending_student_approval | approved | rejected
  const ParentLink({
    required this.linkId,
    required this.parentName,
    required this.linkStatus,
  });
}

/// معلومات مفصل شاگرد — «مشاهدهٔ کامل سابقهٔ تحصیلی» بخش ۱۵.۲.
class StudentDetail {
  final StudentSummary summary;
  final String email;
  final String phone;
  final DateTime birthDate;
  final DateTime registeredAt;
  final List<SubjectProgress> subjects;
  final AttendanceSummary attendance;
  final List<ParentLink> parentLinks;
  final int certificatesCount;
  final int aiConversationsCount;
  final int examsTaken;
  final int classRank; // رتبه در صنف (بخش ۸.۱ — محاسبهٔ سرور)
  final int classSize;

  const StudentDetail({
    required this.summary,
    required this.email,
    required this.phone,
    required this.birthDate,
    required this.registeredAt,
    required this.subjects,
    required this.attendance,
    required this.parentLinks,
    required this.certificatesCount,
    required this.aiConversationsCount,
    required this.examsTaken,
    required this.classRank,
    required this.classSize,
  });
}

/// گزارش استاد هوش مصنوعی دربارهٔ شاگرد — تولیدشده در AI Service (بخش ۵)،
/// ذخیره/بازیابی از Backend. شامل سطح پیشرفت، استرس و مشکلات.
class AiTeacherReport {
  final DateTime generatedAt;
  final double overallProgress; // ۰..۱۰۰
  final Trend trend;
  final StressLevel stressLevel;
  final double engagementScore; // ۰..۱۰۰ — میزان تعامل با AI Teacher
  final List<String> strengths;
  final List<String> concerns; // مشکلات شناسایی‌شده
  final List<String> recommendations;
  final List<SubjectNote> subjectNotes;

  const AiTeacherReport({
    required this.generatedAt,
    required this.overallProgress,
    required this.trend,
    required this.stressLevel,
    required this.engagementScore,
    required this.strengths,
    required this.concerns,
    required this.recommendations,
    required this.subjectNotes,
  });
}

class SubjectNote {
  final String subjectName;
  final String note;
  const SubjectNote({required this.subjectName, required this.note});
}

/// اکشن مدیریتی توسعه‌پذیر (اصل ۸ بخش ۱.۲ — «توسعه‌پذیری بدون بازنویسی»).
/// نیازمندی‌های آیندهٔ مدیر فقط با افزودن یک آیتم به Registry اضافه می‌شوند.
class AdminActionSpec {
  final String id; // e.g. 'suspend', 'soft_delete', 'reset_password'
  final bool destructive;
  final bool requiresTypedConfirmation; // مثل حذف حساب
  const AdminActionSpec({
    required this.id,
    this.destructive = false,
    this.requiresTypedConfirmation = false,
  });
}
