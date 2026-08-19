import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../ai_teacher/presentation/providers/learning_progress_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../curriculum/domain/entities/curriculum_entities.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../../../grade_map/presentation/providers/grade_map_providers.dart';
import '../../data/datasources/study_plan_datasource.dart';
import '../../domain/entities/study_plan.dart';

/// رفع اشکال «منطق مضامین با نصاب درسی فرق دارد»: منبع تعیین مضامین اکنون
/// همان [gradeMapRepositoryProvider] («نصاب درسی»/نقشهٔ صنف) است، نه فقط
/// کتابخانهٔ محلیِ معلم هوشمند — جزئیات کامل در کامنت بالای
/// `StudyPlanDataSource`. این Provider فقط دربارهٔ «کدام مضمون، کدام روز»
/// تصمیم می‌گیرد؛ «کدام درس دقیقاً» را [todaySubjectPointerProvider] پایین‌تر
/// در همین فایل، زنده و بدون کش، تعیین می‌کند.
final studyPlanDataSourceProvider = Provider((ref) => StudyPlanDataSource(
      ref.watch(gradeMapRepositoryProvider),
      ref.watch(learningProgressDataSourceProvider),
      studentId: () => ref.read(authSessionProvider)?.id ?? 'unknown',
    ));

/// «کجای نصاب درسی این مضمون الان دقیقاً ایستاده» — قلبِ رفع اشکال ریشه‌ای
/// «امروز و نصاب درسی یک منبع معلومات را نمی‌گیرند».
///
/// این Provider **هیچ کش/ذخیرهٔ جداگانه‌ای ندارد**: مستقیماً همان
/// [chaptersProvider]/[lessonsProvider]ی خودِ نصاب درسی (`autoDispose`، در
/// `curriculum_providers.dart`) را می‌خواند — دقیقاً همان Providerهایی که
/// `ChaptersScreen`/`LessonsScreen` استفاده می‌کنند. یعنی وقتی شاگرد یک
/// درس را می‌بیند یا کار خانگی‌اش را می‌فرستد (و آن دو Provider — نگاه کنید
/// به `ai_voice_ask_sheet.dart`/`lesson_detail_screen.dart` — بلافاصله
/// Invalidate می‌شوند)، همین لحظه، بدون هیچ تأخیر یا نیاز به «تولید دوبارهٔ»
/// دستیِ برنامهٔ هفتگی، این Provider هم نتیجهٔ تازه می‌دهد و کارت «امروز»
/// خودش را به‌روز می‌کند.
///
/// منطق دقیقاً همان زنجیرهٔ قفلِ نصاب درسی است (`getLessonLockList` سمت
/// سرور):
///  ۱. اولین فصلِ باز-و-ناتمام را پیدا کن.
///  ۲. اگر آزمون آن فصل آماده و منتظر است → `action: 'quiz'`.
///  ۳. وگرنه اولین درسِ باز-و-ندیده را پیدا کن → `action: 'lesson'`.
///  ۴. اگر چنین درسی نبود ولی درسی «دیده‌شده امّا کار خانگی‌اش ارسال نشده»
///     هست → `action: 'homework'` (دقیقاً همان چیزی که درس بعدی را قفل نگه
///     داشته).
///  ۵. هیچ‌کدام (مضمون تمام شده) یا خطای شبکه حین خواندن نصابی که واقعاً
///     وجود دارد → `action: 'chapters'` (صفحهٔ «فصل‌ها»ی نصاب باز می‌شود؛
///     هرگز به گفت‌وگوی آزادِ بدون‌قفل سقوط نمی‌کند).
///  ۶. نصاب این مضمون اصلاً هنوز ساختاربندی نشده (فهرست فصل‌ها واقعاً خالی)
///     → `action: 'chat'` — تنها حالتی که گفت‌وگوی آزاد با معلم هوشمند باز
///     می‌شود، چون اینجا چیزی برای قفل شدن وجود ندارد.
typedef TodaySubjectPointer = ({
  String action,
  String? chapterId,
  String? lessonId,
  String? lessonTitleFa,
});

final todaySubjectPointerProvider =
    FutureProvider.autoDispose.family<TodaySubjectPointer, String>((ref, subjectId) async {
  try {
    final chapters = await ref.watch(chaptersProvider(subjectId).future);
    if (chapters.isEmpty) {
      return (action: 'chat', chapterId: null, lessonId: null, lessonTitleFa: null);
    }

    Chapter? chapter;
    for (final c in chapters) {
      if (c.unlocked && !c.completed) {
        chapter = c;
        break;
      }
    }
    if (chapter == null) {
      return (action: 'chapters', chapterId: null, lessonId: null, lessonTitleFa: null);
    }
    if (chapter.quizPending) {
      return (action: 'quiz', chapterId: chapter.id, lessonId: null, lessonTitleFa: null);
    }

    final lessons = await ref.watch(lessonsProvider(chapter.id).future);
    Lesson? nextLesson;
    for (final l in lessons) {
      if (l.unlocked && !l.viewed) {
        nextLesson = l;
        break;
      }
    }
    if (nextLesson != null) {
      return (
        action: 'lesson',
        chapterId: chapter.id,
        lessonId: nextLesson.id,
        lessonTitleFa: nextLesson.titleFa,
      );
    }

    // هیچ درسِ بازِ‌ندیده‌ای نیست؛ اگر درسی دیده‌شده ولی هنوز کار خانگی‌اش
    // ارسال نشده — همان چیزی است که درس بعدی را قفل نگه داشته.
    Lesson? pendingHomework;
    for (final l in lessons) {
      if (l.viewed && !l.completed) {
        pendingHomework = l;
        break;
      }
    }
    if (pendingHomework != null) {
      return (
        action: 'homework',
        chapterId: chapter.id,
        lessonId: pendingHomework.id,
        lessonTitleFa: pendingHomework.titleFa,
      );
    }

    return (action: 'chapters', chapterId: null, lessonId: null, lessonTitleFa: null);
  } catch (_) {
    // خطای شبکه/سرور — Fail-safe امن: نصاب این مضمون *وجود دارد* ولی الان
    // در دسترس نیست، پس هرگز به گفت‌وگوی آزادِ بدون‌قفل سقوط نمی‌کند؛
    // به‌جایش صفحهٔ «فصل‌ها»ی خودِ نصاب درسی باز می‌شود (که خودش state
    // خطا/تلاش دوباره و قفل واقعی هر فصل را نشان می‌دهد).
    return (action: 'chapters', chapterId: null, lessonId: null, lessonTitleFa: null);
  }
});

/// می‌رود به همان جایی که [pointer] (از [todaySubjectPointerProvider])
/// نشان می‌دهد — منطق ناوبریِ **مشترک** بین کارت «امروز» (خانه،
/// `today_schedule_card.dart`) و صفحهٔ کامل «تقسیم اوقات هفتگی»
/// (`weekly_plan_screen.dart`)، تا هر دو ورودی دقیقاً یک‌جور با نصاب درسی
/// هماهنگ بمانند — رفع اشکال: قبلاً `weekly_plan_screen.dart` مسیر خودش
/// را داشت (همیشه گفت‌وگوی آزادِ بدون‌قفل)، مستقل از این هماهنگ‌سازی.
void openTodaySubjectPointer(
  BuildContext context,
  WidgetRef ref, {
  required String subjectId,
  required TodaySubjectPointer? pointer,
}) {
  final action = pointer?.action;
  final chapterId = pointer?.chapterId;
  final lessonId = pointer?.lessonId;
  if (action == 'lesson' && chapterId != null && lessonId != null) {
    context.push(AppRoutes.curriculumLessonDetail(subjectId, chapterId, lessonId));
    return;
  }
  if (action == 'quiz' && chapterId != null) {
    context.push(AppRoutes.chapterQuiz(subjectId, chapterId));
    return;
  }
  if (action == 'homework') {
    context.push(AppRoutes.homework);
    return;
  }
  if (action == 'chapters') {
    context.push(AppRoutes.curriculumChapters(subjectId));
    return;
  }
  // پیش‌فرض ('chat' یا pointer هنوز null): **فقط** وقتی این مضمون اصلاً
  // هنوز در نصاب درسی ساختاربندی نشده — چیزی برای قفل‌شدن نیست، پس گفت‌وگوی
  // آزاد با معلم هوشمند (رفتار قدیمی) اینجا واقعاً بی‌خطر است.
  ref.read(aiTeacherInitialSubjectProvider.notifier).state = subjectId;
  context.push(AppRoutes.aiTeacher);
}

/// «نبضِ روز» — رفع اشکال پایداری: قبلاً `weeklyPlanProvider`/`todayPlanProvider`
/// فقط یک‌بار در طول عمر برنامه محاسبه می‌شدند و دیگر هرگز خودشان را
/// بازسازی نمی‌کردند؛ اگر شاگرد برنامه را بدون بستن باز نگه می‌داشت (مثلاً
/// از شب تا صبح، یا از پنجشنبه تا شنبه)، «برنامهٔ امروز» همچنان روز/هفتهٔ
/// قبلی را نشان می‌داد. این Stream هر یک دقیقه بررسی می‌کند و فقط وقتی
/// «امروز» واقعاً عوض شود (که شروع هفتهٔ نو را هم همیشه شامل می‌شود) یک
/// مقدار تازه منتشر می‌کند — یعنی بدون بارگذاری/چشمک‌زدن غیرضروری در طول روز.
final _dayPulseProvider = StreamProvider.autoDispose<String>((ref) async* {
  String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  var current = key(DateTime.now());
  yield current;
  await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
    final next = key(DateTime.now());
    if (next != current) {
      current = next;
      yield next;
    }
  }
});

/// تقسیم اوقات هفتهٔ جاری **صنف فعال واقعی شاگرد** — خودکار هفته‌ای یک‌بار
/// ساخته می‌شود و با ارتقای صنف خودکار برای صنف جدید بازسازی می‌شود؛ با
/// گذشت روز/هفته هم خودکار به‌روز می‌ماند (نه فقط با بستن و باز کردن دوبارهٔ
/// برنامه).
final weeklyPlanProvider = FutureProvider<WeeklyStudyPlan>((ref) async {
  final grade = ref.watch(activeGradeProvider);
  ref.watch(_dayPulseProvider);
  // با تغییر پیشرفت، برنامهٔ ذخیره‌شده همچنان معتبر است؛ فقط با
  // regeneratePlan یا شروع هفتهٔ نو عوض می‌شود (منطق آن در دیتاسورس است).
  return ref.read(studyPlanDataSourceProvider).getCurrentPlan(grade: grade);
});

/// برنامهٔ امروز (روز جاری هفته) — با گذشت نیمه‌شب خودکار روز جدید را نشان
/// می‌دهد چون به [_dayPulseProvider] هم وابسته است.
final todayPlanProvider = FutureProvider<PlanDay?>((ref) async {
  final plan = await ref.watch(weeklyPlanProvider.future);
  ref.watch(_dayPulseProvider);
  return plan.dayFor(DateTime.now());
});

/// تولید دوبارهٔ دستی برنامه (دکمهٔ «برنامهٔ نو بساز»).
final regeneratePlanProvider = Provider((ref) => () async {
      final grade = ref.read(activeGradeProvider);
      await ref
          .read(studyPlanDataSourceProvider)
          .getCurrentPlan(regenerate: true, grade: grade);
      ref.invalidate(weeklyPlanProvider);
    });
