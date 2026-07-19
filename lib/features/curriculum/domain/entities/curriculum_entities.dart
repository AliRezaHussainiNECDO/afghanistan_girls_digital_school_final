import 'package:equatable/equatable.dart';

/// طبق بخش ۱۷.۲ سند: `chapters` سطح بالا، `units` زیرتقسیم اختیاری،
/// `lessons` می‌تواند مستقیم زیر Chapter یا زیر Unit باشد.
///
/// [unlocked] و [completed] منطق قفل‌گشایی ترتیبی را پیاده می‌کنند: فصل اول
/// همیشه باز است؛ فصل بعدی فقط بعد از تکمیل فصل قبلی باز می‌شود (محاسبه‌شده
/// در سرور، `backend/src/lib/progress.ts`، تا با سایر داشبوردها یکسان باشد).
class Chapter extends Equatable {
  final String id;
  final String titleFa;
  final int orderIndex;
  final int lessonCount;
  final int viewedCount;
  final double progressPercent;
  final bool completed;
  final bool unlocked;
  final String? sourceBookId;

  const Chapter({
    required this.id,
    required this.titleFa,
    required this.orderIndex,
    required this.lessonCount,
    this.viewedCount = 0,
    this.progressPercent = 0,
    this.completed = false,
    this.unlocked = true,
    this.sourceBookId,
  });

  @override
  List<Object?> get props => [id, viewedCount, completed, unlocked];
}

class Lesson extends Equatable {
  final String id;
  final String chapterId;
  final String titleFa;
  final int estimatedMinutes;
  final bool viewed; // طبق C1 بخش ۶.۲ — Backend صاحب حقیقت است
  final String contentBody;

  const Lesson({
    required this.id,
    required this.chapterId,
    required this.titleFa,
    required this.estimatedMinutes,
    required this.viewed,
    required this.contentBody,
  });

  @override
  List<Object?> get props => [id, viewed];
}

/// نتیجهٔ ثبت بازدید یک درس — برای بازخورد فوری در UI (امتیاز/جشن تکمیل
/// فصل) طبق سیستم امتیازدهی بر اساس فعالیت (Gamification).
/// نتیجهٔ «این درس را یاد گرفتم» — طبق `POST /lessons/{id}/learned`:
/// برای هر (شاگرد، درس) فقط یک کار خانگی ساخته می‌شود؛ زدن دوبارهٔ دکمه روی
/// همان درس [alreadyAssigned] برمی‌گرداند، نه کار خانگی تکراری.
class LessonLearnedResult extends Equatable {
  final bool assigned;
  final bool alreadyAssigned;

  const LessonLearnedResult({required this.assigned, required this.alreadyAssigned});

  @override
  List<Object?> get props => [assigned, alreadyAssigned];
}

class LessonViewResult extends Equatable {
  final int pointsAwarded;
  final bool chapterJustCompleted;
  final int chapterBonusAwarded;

  const LessonViewResult({
    required this.pointsAwarded,
    required this.chapterJustCompleted,
    required this.chapterBonusAwarded,
  });

  int get totalPointsThisAction => pointsAwarded + chapterBonusAwarded;

  @override
  List<Object?> get props => [pointsAwarded, chapterJustCompleted, chapterBonusAwarded];
}
