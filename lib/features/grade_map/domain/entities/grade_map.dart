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
  final bool gradeLocked;
  final double gradeAveragePercent;
  final double attendanceRatePercent;
  final List<GradeMapSubjectEntry> subjects;

  const GradeMap({
    required this.gradeNumber,
    required this.gradeLocked,
    required this.gradeAveragePercent,
    required this.attendanceRatePercent,
    required this.subjects,
  });

  @override
  List<Object?> get props => [gradeNumber, gradeLocked, subjects];
}
