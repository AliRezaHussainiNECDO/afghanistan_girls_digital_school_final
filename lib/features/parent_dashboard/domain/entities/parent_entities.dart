import 'package:equatable/equatable.dart';

/// اشتراک واقعیِ فرزند در یک سمینار مشخص — رفع اشکال: قبلاً این فیلد صرفاً
/// «۳ سمینار آیندهٔ همهٔ شاگردان» بود (بدون ربط به اینکه همین فرزند واقعاً
/// ثبت‌نام کرده یا نه). حالا از `seminar_registrations` خودِ همین شاگرد
/// می‌آید و وضعیت واقعی هرکدام را هم دارد.
class ChildSeminarParticipation extends Equatable {
  final String title;
  final DateTime scheduledStart;

  /// registered | waitlisted | attended | no_show
  final String status;

  const ChildSeminarParticipation({
    required this.title,
    required this.scheduledStart,
    required this.status,
  });

  bool get isUpcoming => scheduledStart.isAfter(DateTime.now());

  @override
  List<Object?> get props => [title, scheduledStart, status];
}

class LinkedChild extends Equatable {
  final String studentId;
  final String displayName;
  const LinkedChild({required this.studentId, required this.displayName});
  @override
  List<Object?> get props => [studentId];
}

class ChildSubjectSummary extends Equatable {
  final String subjectNameFa;
  final String statusLabel; // completed/in_progress/locked — نمایش آماده از Backend
  final double? finalScore;

  /// درصد پیشرفت درسیِ همین مضمون — همان منطق واحد پیشرفت که در بخش فصل‌های
  /// شاگرد (`getChapterList`/`getSubjectProgressList`) محاسبه می‌شود؛ طبق
  /// درخواست کاربر باید در داشبورد والدین هم مطابق همان‌جا نمایش یابد.
  final double? progressPercent;

  const ChildSubjectSummary({
    required this.subjectNameFa,
    required this.statusLabel,
    this.finalScore,
    this.progressPercent,
  });
  @override
  List<Object?> get props => [subjectNameFa];
}

/// خروجی Allow-list دقیق `GET /parents/{parentId}/children/{studentId}/summary`
/// — طبق بخش ۱۳ب.۳ سند (**فقط** فیلدهای زیر، نه یک Endpoint عمومی فیلترشده).
class ChildSummary extends Equatable {
  final String studentId;
  final String displayName;
  final int gradeNumber;
  final double gradeCompletionPercent;
  final double attendanceRatePercent;
  final List<ChildSubjectSummary> subjects;
  final List<String> achievements;
  final List<String> certificates;
  final List<ChildSeminarParticipation> seminarParticipation;

  /// امتیاز فعالیت (Gamification) — همان منبع `getPointsSummary` سرور که در
  /// داشبورد شاگرد هم استفاده می‌شود، تا والدین همان تشویق/سطح را ببینند.
  final int pointsTotal;
  final int pointsLevel;
  final String pointsLevelTitleFa;

  const ChildSummary({
    required this.studentId,
    required this.displayName,
    required this.gradeNumber,
    required this.gradeCompletionPercent,
    required this.attendanceRatePercent,
    required this.subjects,
    required this.achievements,
    required this.certificates,
    required this.seminarParticipation,
    this.pointsTotal = 0,
    this.pointsLevel = 1,
    this.pointsLevelTitleFa = 'نوآموز',
  });

  @override
  List<Object?> get props => [studentId];
}
