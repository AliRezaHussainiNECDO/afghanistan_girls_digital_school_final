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

  /// رفع اشکال: قبلاً شاگرد بعد از دیدن همهٔ درس‌های یک فصلی که «آزمون
  /// فصل» با AI برایش ساخته شده بود، هیچ نشانه/دکمه‌ای برای رفتن به همان
  /// آزمون نمی‌دید — فصل با پیشرفت ۱۰۰٪ برای همیشه «در حال انجام» می‌ماند
  /// (backend/src/lib/progress.ts::getChapterList این را محاسبه می‌کرد ولی
  /// هرگز به کلاینت نمی‌فرستاد). این پرچم دقیقاً همان حالت را مشخص می‌کند.
  final bool quizPending;

  /// نصاب چندزبانه (اول پشتو): وقتی کاربر زبانی غیر از دری انتخاب کرده و
  /// سرور با `?lang=` صدا زده شده، این پرچم نشان می‌دهد آیا [titleFa] واقعاً
  /// ترجمهٔ منتشرشدهٔ همان زبان است یا (چون هنوز ترجمه نشده) دری اصلی به‌عنوان
  /// Fallback برگشته — تا UI بتواند نشان کوچک «هنوز ترجمه نشده» نمایش دهد.
  /// وقتی زبان دری است یا اصلاً `lang` فرستاده نشده، همیشه true است (بدون نشان).
  final bool translated;

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
    this.quizPending = false,
    this.translated = true,
  });

  @override
  List<Object?> get props => [id, viewedCount, completed, unlocked, quizPending, translated];
}

class Lesson extends Equatable {
  final String id;
  final String chapterId;
  final String titleFa;
  final int estimatedMinutes;
  final bool viewed; // طبق C1 بخش ۶.۲ — Backend صاحب حقیقت است

  /// 🔒 قفل زنجیره‌ای دروس (Prerequisite Locking — سرور-محور،
  /// `backend/src/lib/progress.ts::getLessonLockList`): درس بعدی فقط وقتی باز
  /// می‌شود که درس قبلی ۱۰۰٪ تکمیل شده باشد («یاد گرفتم» + ثبت کار خانگی).
  final bool unlocked;

  /// تکمیل کامل زنجیره برای همین درس (یاد گرفتم + کار خانگی ثبت‌شده).
  final bool completed;
  final String contentBody;

  /// مثل [Chapter.translated] — نشان می‌دهد آیا عنوان/متن این درس ترجمهٔ
  /// منتشرشدهٔ زبان انتخابی است یا دری اصلی (Fallback).
  final bool translated;

  const Lesson({
    required this.id,
    required this.chapterId,
    required this.titleFa,
    required this.estimatedMinutes,
    required this.viewed,
    required this.contentBody,
    this.unlocked = true,
    this.completed = false,
    this.translated = true,
  });

  @override
  List<Object?> get props => [id, viewed, unlocked, completed, translated];
}

/// نتیجهٔ ثبت بازدید یک درس — برای بازخورد فوری در UI (امتیاز/جشن تکمیل
/// فصل) طبق سیستم امتیازدهی بر اساس فعالیت (Gamification).
/// نتیجهٔ «این درس را یاد گرفتم» — طبق `POST /lessons/{id}/learned`:
/// برای هر (شاگرد، درس) فقط یک کار خانگی ساخته می‌شود؛ زدن دوبارهٔ دکمه روی
/// همان درس [alreadyAssigned] برمی‌گرداند، نه کار خانگی تکراری.
class LessonLearnedResult extends Equatable {
  final bool assigned;
  final bool alreadyAssigned;

  /// سهمیهٔ رایگان Gemini موقتاً تمام شده (HTTP 429 سمت سرور) — UI باید
  /// SnackBar محترمانهٔ «قفل موقت سیستم» نشان دهد، نه پیام خطای عمومی.
  final bool rateLimited;

  const LessonLearnedResult({
    required this.assigned,
    required this.alreadyAssigned,
    this.rateLimited = false,
  });

  @override
  List<Object?> get props => [assigned, alreadyAssigned, rateLimited];
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
