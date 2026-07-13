import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../shared_models/subject.dart';
import '../../../ai_teacher/presentation/providers/learning_progress_providers.dart';
import '../../domain/entities/study_plan.dart';
import '../providers/study_plan_providers.dart';

/// کارت «برنامهٔ درسی امروز من» در صفحهٔ خانه — قلب تپندهٔ یادگیری روزانه:
/// مضامینی که هوش مصنوعی برای امروز برنامه‌ریزی کرده، با پیشرفت هر مضمون و
/// دکمهٔ «ادامهٔ درس» که مستقیم معلم هوشمند همان مضمون را باز می‌کند.
class TodayScheduleCard extends ConsumerWidget {
  const TodayScheduleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final todayAsync = ref.watch(todayPlanProvider);
    final progressAsync = ref.watch(learningProgressProvider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('برنامهٔ درسی امروز من',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text(
                      PlanDay.namesFa[DateTime.now().weekday] ?? '',
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.studyPlan),
                child: const Text('برنامهٔ هفته'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          todayAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('خطا در بارگذاری برنامه: $e',
                style: TextStyle(color: scheme.error, fontSize: 12)),
            data: (day) {
              if (day == null || day.isRestDay) {
                return _RestDayBanner(
                    isFriday: DateTime.now().weekday == DateTime.friday);
              }
              final progressMap = progressAsync.maybeWhen(
                data: (list) => {for (final p in list) p.subjectId: p},
                orElse: () => <String, dynamic>{},
              );
              return Column(
                children: [
                  for (var i = 0; i < day.slots.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _SlotTile(
                      slot: day.slots[i],
                      order: i + 1,
                      percent: progressMap[day.slots[i].subjectId]?.percent
                              ?.toDouble() ??
                          0.0,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RestDayBanner extends StatelessWidget {
  final bool isFriday;
  const _RestDayBanner({required this.isFriday});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        children: [
          Icon(isFriday ? Icons.self_improvement_rounded : Icons.menu_book_rounded,
              size: 34, color: scheme.primary),
          const SizedBox(height: 8),
          Text(
            isFriday
                ? 'امروز جمعه است — روز استراحت! 🌸 اگر دوست داشتی می‌توانی درس‌های هفته را مرور کنی.'
                : 'هنوز کتابی وارد نشده تا برنامهٔ درسی ساخته شود. از مدیر بخواه کتاب‌های نصاب را وارد کند.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _SlotTile extends ConsumerWidget {
  final StudySlot slot;
  final int order;
  final double percent;
  const _SlotTile(
      {required this.slot, required this.order, required this.percent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final subject = mockSubjects.firstWhere((s) => s.id == slot.subjectId,
        orElse: () => mockSubjects.first);
    final color = Color(subject.colorValue);

    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () {
          ref.read(aiTeacherInitialSubjectProvider.notifier).state =
              slot.subjectId;
          context.push(AppRoutes.aiTeacher);
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // شمارهٔ جلسه + حلقهٔ پیشرفت مضمون
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 4,
                      backgroundColor: color.withValues(alpha: .15),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    Text('$order',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: color)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(slot.subjectNameFa,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${slot.minutes} دقیقه',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: color)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(slot.focusFa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: color.withValues(alpha: .12),
                    shape: BoxShape.circle),
                child: Icon(Icons.play_arrow_rounded, color: color, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
