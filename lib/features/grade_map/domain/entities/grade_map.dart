import 'package:equatable/equatable.dart';

/// وضعیت‌های `student_progress.status` — طبق بخش ۱۷.۲ سند (پوشش کامل
/// State Machine بخش ۶.۵)؛ Client فقط این وضعیت را نمایش می‌دهد،
/// هرگز خودش تصمیم نمی‌گیرد (اصل بخش ۴).
enum SubjectProgressStatus {
  locked,
  unlocked,
  inProgress,
  completed,
  failed,
  retryWindow,
  remedialRequired,
}

class GradeMapSubjectEntry extends Equatable {
  final String subjectId;
  final String subjectNameFa;
  final SubjectProgressStatus status;
  final double? finalScore; // Final_Subject_Score — بخش ۶.۳
  final double completionPercent; // برای نوار پیشرفت (٪ درس‌های دیده‌شده)

  const GradeMapSubjectEntry({
    required this.subjectId,
    required this.subjectNameFa,
    required this.status,
    this.finalScore,
    this.completionPercent = 0,
  });

  @override
  List<Object?> get props => [subjectId, status, finalScore];
}

/// خروجی `GET /students/{id}/grade-map` — طبق بخش ۱۹.۲/۲۴.۳ سند.
/// این کلاس دقیقاً همان چیزی است که Backend محاسبه و آمادهٔ نمایش می‌فرستد.
class GradeMap extends Equatable {
  final int gradeNumber;

  /// صنف فعال واقعیِ شاگرد در حال حاضر — ممکن است با [gradeNumber] فرق کند
  /// اگر این پاسخ برای مرور یکی از صنوف پایین‌ترِ تکمیل‌شده درخواست شده
  /// باشد (رفع اشکال: قبلاً امکان تشخیص «این صنفِ فعال است یا صنفِ
  /// تکمیل‌شدهٔ مرورشده» برای کلاینت وجود نداشت).
  final int activeGradeNumber;
  final bool gradeLocked;
  final double gradeAveragePercent;
  final double attendanceRatePercent;
  final List<GradeMapSubjectEntry> subjects;

  /// آیا [gradeNumber] همان صنف فعال شاگرد است یا یک صنفِ پایین‌ترِ
  /// تکمیل‌شده که فقط برای مرور باز شده.
  bool get isActiveGrade => gradeNumber == activeGradeNumber;

  /// وضعیت واقعی ارتقا — محاسبه‌شدهٔ سرور (رفع اشکال: قبلاً این وضعیت فقط
  /// در «انبار ارتقای» محلی گوشی شبیه‌سازی می‌شد و با نصاب واقعی هماهنگ
  /// نبود). طبق اصل بخش ۴: کلاینت فقط این مقادیر را نمایش می‌دهد.
  final bool allSubjectsComplete;
  final bool examPassed;
  final double? examBestScore;
  final bool canPromote;

  const GradeMap({
    required this.gradeNumber,
    int? activeGradeNumber,
    required this.gradeLocked,
    required this.gradeAveragePercent,
    required this.attendanceRatePercent,
    required this.subjects,
    this.allSubjectsComplete = false,
    this.examPassed = false,
    this.examBestScore,
    this.canPromote = false,
  }) : activeGradeNumber = activeGradeNumber ?? gradeNumber;

  @override
  List<Object?> get props => [gradeNumber, activeGradeNumber, gradeLocked, subjects, canPromote];
}
