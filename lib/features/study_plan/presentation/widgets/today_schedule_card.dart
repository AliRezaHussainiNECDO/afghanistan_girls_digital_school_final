import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../shared_models/subject.dart';
import '../../../ai_teacher/presentation/providers/learning_progress_providers.dart';
import '../../domain/entities/study_plan.dart';
import '../providers/study_plan_providers.dart';

/// کارت «برنامهٔ درسی امروز من» در صفحهٔ خانه — قلب تپندهٔ یادگیری روزانه:
/// مضامینی که هوش مصنوعی برای امروز برنامه‌ریزی کرده، با پیشرفت هر مضمون و
/// دکمهٔ «ادامهٔ درس» که مستقیم معلم هوشمند همان مضمون را باز می‌کند.
///
/// رفع اشکال پایداری: قبلاً `todayPlanProvider`/`weeklyPlanProvider` فقط
/// یک‌بار محاسبه می‌شدند و اگر برنامه بدون بسته شدن باز می‌ماند (شب تا صبح،
/// یا پنجشنبه تا شنبه)، این کارت همچنان روز/هفتهٔ قبلی را نشان می‌داد؛ حالا
/// (`study_plan_providers.dart`) با گذشت روز خودکار به‌روز می‌شود.
class TodayScheduleCard extends ConsumerWidget {
  const TodayScheduleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // با watch شدن به‌جای skipLoadingOnReload، بازسازی خودکار روزانه باعث
    // چشمک‌زدن نمی‌شود چون AsyncLoading حاصل از reload مقدار قبلی را نگه
    // می‌دارد و پایین همیشه با .valueOrNull خوانده می‌شود.
    final todayAsync = ref.watch(todayPlanProvider);
    final planAsync = ref.watch(weeklyPlanProvider);
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
                    Text(context.tr('studyPlan.todayTitle'),
                        style: const TextStyle(
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
                child: Text(context.tr('studyPlan.weekPlanButton')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final day = todayAsync.valueOrNull;

            if (todayAsync.isLoading && day == null) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            if (todayAsync.hasError && day == null) {
              return _TodayErrorState(
                error: todayAsync.error!,
                onRetry: () {
                  ref.invalidate(weeklyPlanProvider);
                  ref.invalidate(todayPlanProvider);
                },
              );
            }

            if (day == null || day.isRestDay) {
              return _RestDayBanner(
                  isFriday: DateTime.now().weekday == DateTime.friday);
            }

            final generatedBy = planAsync.valueOrNull?.generatedBy;
            final totalMinutes =
                day.slots.fold<int>(0, (sum, s) => sum + s.minutes);
            final progressMap = progressAsync.maybeWhen(
              data: (list) => {for (final p in list) p.subjectId: p},
              orElse: () => const <String, dynamic>{},
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (generatedBy != null)
                      _MiniBadge(
                        icon: generatedBy == 'ai'
                            ? Icons.auto_awesome_rounded
                            : Icons.psychology_alt_rounded,
                        label: generatedBy == 'ai'
                            ? context.tr('studyPlan.generatedByAi')
                            : context.tr('studyPlan.generatedBySmart'),
                      ),
                    const Spacer(),
                    _MiniBadge(
                      icon: Icons.timer_outlined,
                      label: context.tr(
                          'studyPlan.todayMinutesLabel', {'minutes': '$totalMinutes'}),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < day.slots.length; i++) ...[
                  if (i > 0) const SizedBox(height: 8),
                  _SlotTile(
                    slot: day.slots[i],
                    order: i + 1,
                    percent: progressMap[day.slots[i].subjectId]?.percent
                            ?.toDouble() ??
                        0.0,
                  )
                      .animate(delay: (60 * i).ms)
                      .fadeIn(duration: 260.ms)
                      .slideX(begin: 0.06, end: 0, duration: 260.ms, curve: Curves.easeOutCubic),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: scheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer)),
        ],
      ),
    );
  }
}

class _TodayErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _TodayErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 28, color: scheme.error),
          const SizedBox(height: 8),
          Text(
            context.tr('studyPlan.loadError', {'error': '$error'}),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(context.tr('common.retry')),
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isFriday
            ? AppColors.sunriseGradient
            : LinearGradient(
                colors: [
                  scheme.surfaceContainerHigh,
                  scheme.surfaceContainerHighest,
                ],
              ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isFriday
                  ? Colors.white.withValues(alpha: .22)
                  : scheme.primary.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isFriday ? Icons.self_improvement_rounded : Icons.menu_book_rounded,
              size: 26,
              color: isFriday ? Colors.white : scheme.primary,
            ),
          ).animate().scale(
                begin: const Offset(0.6, 0.6),
                end: const Offset(1, 1),
                duration: 320.ms,
                curve: Curves.easeOutBack,
              ),
          const SizedBox(height: 10),
          Text(
            isFriday
                ? context.tr('studyPlan.fridayRest')
                : context.tr('studyPlan.noBooksYet'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: isFriday ? Colors.white : scheme.onSurface,
            ),
          ),
          if (!isFriday) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: 220,
              child: AppPrimaryButton(
                label: context.tr('studyPlan.browseBooksCta'),
                icon: Icons.menu_book_rounded,
                onPressed: () => context.push(AppRoutes.curriculum),
              ),
            ),
          ],
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                          child: Text(context.tr('curriculum.estimatedMinutes', {'minutes': '${slot.minutes}'}),
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
