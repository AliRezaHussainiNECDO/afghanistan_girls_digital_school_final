import 'package:equatable/equatable.dart';

/// یک «جلسهٔ درسی» در تقسیم اوقات — واحد پایهٔ برنامهٔ روزانه.
///
/// **این کلاس عمداً فقط دربارهٔ «کدام مضمون، چه مدت، آیا تازه است» است —
/// نه «کدام درس/فصل دقیقاً باز است».** آن بخش (که باید همیشه تازه/زنده
/// باشد، نه هفته‌ای یک‌بار Cache‌شده) از `todaySubjectPointerProvider`
/// (در `study_plan_providers.dart`) خوانده می‌شود — همان Provider که
/// مستقیماً `chaptersProvider`/`lessonsProvider`ی خودِ نصاب درسی را
/// می‌خواند. این جداسازی دقیقاً رفع اشکال ریشه‌ای «امروز و نصاب درسی یک
/// منبع معلومات ندارند» است: قبلاً «کدام درس» هم همین‌جا محاسبه و در
/// SharedPreferences ذخیره می‌شد، پس تا آخر هفته (یا تا «تولید دوباره»)
/// حتی بعد از ارسال کار خانگی به‌روز نمی‌شد؛ حالا هیچ اشارهٔ درس/فصلی اینجا
/// ذخیره نمی‌شود، فقط در لحظهٔ نمایش، زنده، از همان نصاب درسی خوانده می‌شود.
class StudySlot extends Equatable {
  final String subjectId;
  final String subjectNameFa;

  /// توضیح انگیزشیِ Fail-safe — فقط وقتی نمایش داده می‌شود که نصاب این
  /// مضمون اصلاً ساختاربندی نشده (چیزی برای قفل شدن نیست)؛ در غیر این
  /// صورت UI همیشه پیام زندهٔ `todaySubjectPointerProvider` را نشان می‌دهد.
  final String focusFa;
  final int minutes;

  /// این مضمون امروز اولین‌بار به شاگرد «پیشنهاد» می‌شود (هنوز شروع نکرده،
  /// این هفته هم برایش تازه است) — کارت UI برایش نشان «مضمون جدید» می‌گذارد
  /// تا برنامهٔ امروز واقعاً مثل یک کاریکولم زنده حس شود، نه فهرست ثابت.
  final bool isNew;

  const StudySlot({
    required this.subjectId,
    required this.subjectNameFa,
    required this.focusFa,
    this.minutes = 45,
    this.isNew = false,
  });

  Map<String, dynamic> toJson() => {
        'subjectId': subjectId,
        'subjectNameFa': subjectNameFa,
        'focusFa': focusFa,
        'minutes': minutes,
        'isNew': isNew,
      };

  factory StudySlot.fromJson(Map<String, dynamic> j) => StudySlot(
        subjectId: j['subjectId'] as String,
        subjectNameFa: j['subjectNameFa'] as String? ?? '',
        focusFa: j['focusFa'] as String? ?? '',
        minutes: j['minutes'] as int? ?? 45,
        isNew: j['isNew'] as bool? ?? false,
      );

  @override
  List<Object?> get props => [subjectId, focusFa, minutes, isNew];
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
