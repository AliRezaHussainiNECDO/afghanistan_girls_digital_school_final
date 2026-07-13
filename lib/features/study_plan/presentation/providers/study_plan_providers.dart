import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/student/selected_grade_provider.dart';
import '../../../ai_teacher/presentation/providers/learning_progress_providers.dart';
import '../../data/datasources/study_plan_datasource.dart';
import '../../domain/entities/study_plan.dart';

final studyPlanDataSourceProvider = Provider(
    (ref) => StudyPlanDataSource(ref.watch(learningProgressDataSourceProvider)));

/// تقسیم اوقات هفتهٔ جاری **صنف فعال واقعی شاگرد** — خودکار هفته‌ای یک‌بار
/// ساخته می‌شود و با ارتقای صنف خودکار برای صنف جدید بازسازی می‌شود.
final weeklyPlanProvider = FutureProvider<WeeklyStudyPlan>((ref) async {
  final grade = ref.watch(activeGradeProvider);
  // با تغییر پیشرفت، برنامهٔ ذخیره‌شده همچنان معتبر است؛ فقط با
  // regeneratePlan یا شروع هفتهٔ نو عوض می‌شود.
  return ref.read(studyPlanDataSourceProvider).getCurrentPlan(grade: grade);
});

/// برنامهٔ امروز (روز جاری هفته).
final todayPlanProvider = FutureProvider<PlanDay?>((ref) async {
  final plan = await ref.watch(weeklyPlanProvider.future);
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
