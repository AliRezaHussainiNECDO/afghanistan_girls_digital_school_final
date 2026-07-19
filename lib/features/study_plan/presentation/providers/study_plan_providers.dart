import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/student/selected_grade_provider.dart';
import '../../../ai_teacher/presentation/providers/learning_progress_providers.dart';
import '../../data/datasources/study_plan_datasource.dart';
import '../../domain/entities/study_plan.dart';

final studyPlanDataSourceProvider = Provider(
    (ref) => StudyPlanDataSource(ref.watch(learningProgressDataSourceProvider)));

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
