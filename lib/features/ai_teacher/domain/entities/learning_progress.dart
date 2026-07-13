import 'package:equatable/equatable.dart';

/// پیشرفت یادگیری شاگرد در یک مضمون — «دروس مطالعه‌شده و یادگرفته‌شده»
/// به‌صورت محلی ذخیره می‌شود و معلم هوشمند هر بار از همان‌جا ادامه می‌دهد.
class SubjectLearningProgress extends Equatable {
  final String subjectId;
  final String subjectNameFa;

  /// مجموع بخش‌های قابل‌تدریس کتابِ صنفِ شاگرد (۰ = کتابی وارد نشده).
  final int totalSections;

  /// بخشی که تدریس به آن رسیده (ادامهٔ درس از همین‌جا).
  final int currentSectionIndex;

  /// تعداد بخش‌هایی که شاگرد به سوال آن‌ها پاسخ داده («یادگرفته‌شده»).
  final int masteredSections;

  final DateTime? lastStudiedAt;

  const SubjectLearningProgress({
    required this.subjectId,
    required this.subjectNameFa,
    required this.totalSections,
    required this.currentSectionIndex,
    required this.masteredSections,
    this.lastStudiedAt,
  });

  bool get hasBook => totalSections > 0;

  double get percent => totalSections == 0
      ? 0
      : (masteredSections / totalSections * 100).clamp(0, 100).toDouble();

  /// چند روز از آخرین مطالعه گذشته (برای اولویت‌بندی تقسیم اوقات).
  int get daysSinceStudy => lastStudiedAt == null
      ? 999
      : DateTime.now().difference(lastStudiedAt!).inDays;

  @override
  List<Object?> get props =>
      [subjectId, totalSections, currentSectionIndex, masteredSections, lastStudiedAt];
}
