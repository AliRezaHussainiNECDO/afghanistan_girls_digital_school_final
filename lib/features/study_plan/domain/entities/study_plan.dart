import 'package:equatable/equatable.dart';

/// یک «جلسهٔ درسی» در تقسیم اوقات — واحد پایهٔ برنامهٔ روزانه.
class StudySlot extends Equatable {
  final String subjectId;
  final String subjectNameFa;

  /// توضیح تمرکز جلسه، مثلاً «ادامه از بخش ۱۲ کتاب» یا «مرور بخش‌های قبلی».
  final String focusFa;
  final int minutes;

  const StudySlot({
    required this.subjectId,
    required this.subjectNameFa,
    required this.focusFa,
    this.minutes = 45,
  });

  Map<String, dynamic> toJson() => {
        'subjectId': subjectId,
        'subjectNameFa': subjectNameFa,
        'focusFa': focusFa,
        'minutes': minutes,
      };

  factory StudySlot.fromJson(Map<String, dynamic> j) => StudySlot(
        subjectId: j['subjectId'] as String,
        subjectNameFa: j['subjectNameFa'] as String? ?? '',
        focusFa: j['focusFa'] as String? ?? '',
        minutes: j['minutes'] as int? ?? 45,
      );

  @override
  List<Object?> get props => [subjectId, focusFa, minutes];
}

/// برنامهٔ یک روز — weekday مطابق DateTime.weekday (شنبه=6، جمعه=5).
class PlanDay extends Equatable {
  final int weekday;
  final List<StudySlot> slots;

  const PlanDay({required this.weekday, required this.slots});

  bool get isRestDay => slots.isEmpty;

  static const namesFa = {
    DateTime.saturday: 'شنبه',
    DateTime.sunday: 'یکشنبه',
    DateTime.monday: 'دوشنبه',
    DateTime.tuesday: 'سه‌شنبه',
    DateTime.wednesday: 'چهارشنبه',
    DateTime.thursday: 'پنجشنبه',
    DateTime.friday: 'جمعه',
  };

  String get nameFa => namesFa[weekday] ?? '';

  Map<String, dynamic> toJson() =>
      {'weekday': weekday, 'slots': slots.map((s) => s.toJson()).toList()};

  factory PlanDay.fromJson(Map<String, dynamic> j) => PlanDay(
        weekday: j['weekday'] as int,
        slots: (j['slots'] as List? ?? [])
            .map((e) => StudySlot.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  @override
  List<Object?> get props => [weekday, slots];
}

/// تقسیم اوقات هفتگی — توسط هوش مصنوعی (Ollama) یا الگوریتم محلی ساخته
/// می‌شود و هفته‌ای یک‌بار به‌روز می‌گردد. هفتهٔ تعلیمی: شنبه تا پنجشنبه؛
/// جمعه رخصتی است.
class WeeklyStudyPlan extends Equatable {
  final String weekKey; // مثل '2026-W27'
  final DateTime generatedAt;

  /// 'ai' = ساخته‌شده توسط مدل Ollama | 'smart' = الگوریتم اولویت‌بندی محلی
  final String generatedBy;
  final List<PlanDay> days;

  const WeeklyStudyPlan({
    required this.weekKey,
    required this.generatedAt,
    required this.generatedBy,
    required this.days,
  });

  PlanDay? dayFor(DateTime date) {
    for (final d in days) {
      if (d.weekday == date.weekday) return d;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'weekKey': weekKey,
        'generatedAt': generatedAt.toIso8601String(),
        'generatedBy': generatedBy,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory WeeklyStudyPlan.fromJson(Map<String, dynamic> j) => WeeklyStudyPlan(
        weekKey: j['weekKey'] as String,
        generatedAt:
            DateTime.tryParse(j['generatedAt'] as String? ?? '') ?? DateTime.now(),
        generatedBy: j['generatedBy'] as String? ?? 'smart',
        days: (j['days'] as List? ?? [])
            .map((e) => PlanDay.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  @override
  List<Object?> get props => [weekKey, generatedAt, generatedBy, days];
}
