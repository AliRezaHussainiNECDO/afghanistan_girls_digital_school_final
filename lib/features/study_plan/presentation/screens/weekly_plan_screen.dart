import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared_models/subject.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/study_plan.dart';
import '../providers/study_plan_providers.dart';

/// صفحهٔ «تقسیم اوقات هفتگی من» — برنامهٔ کامل شنبه تا جمعه، ساخته‌شده توسط
/// هوش مصنوعی (یا الگوریتم هوشمند محلی) بر اساس پیشرفت واقعی شاگرد.
class WeeklyPlanScreen extends ConsumerStatefulWidget {
  const WeeklyPlanScreen({super.key});

  @override
  ConsumerState<WeeklyPlanScreen> createState() => _WeeklyPlanScreenState();
}

class _WeeklyPlanScreenState extends ConsumerState<WeeklyPlanScreen> {
  bool _regenerating = false;

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    await ref.read(regeneratePlanProvider)();
    if (mounted) {
      setState(() => _regenerating = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('studyPlan.regenerated'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final planAsync = ref.watch(weeklyPlanProvider);
    // صنف فعال واقعی شاگرد — همان صنفی که در نقشهٔ صنوف/داشبورد نشان داده
    // می‌شود؛ اینجا دیگر قابل تغییر دستی نیست (شاگرد فقط به صنف خودش
    // دسترسی دارد، طبق ماتریس مجوزها).
    final grade = ref.watch(activeGradeProvider);

    return AppScaffold(
      title: context.tr('studyPlan.title'),
      role: AppUserRole.student,
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(context.tr('studyPlan.errorLoading', {'error': '$e'}))),
        data: (plan) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // ── سربرگ: سازنده + صنف + دکمهٔ تولید دوباره ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.heroGradient,
                borderRadius: BorderRadius.circular(AppRadii.xl),
              ),
              child: Row(
                children: [
                  Icon(
                    plan.generatedBy == 'ai'
                        ? Icons.auto_awesome_rounded
                        : Icons.psychology_alt_rounded,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.generatedBy == 'ai'
                              ? context.tr('studyPlan.generatedByAi')
                              : context.tr('studyPlan.generatedBySmart'),
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                            context.tr('studyPlan.gradeWeek',
                                {'grade': '$grade', 'week': plan.weekKey}),
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .9),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr('studyPlan.regenerateTooltip'),
                    onPressed: _regenerating ? null : _regenerate,
                    icon: _regenerating
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.refresh_rounded,
                            color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // ── صنف من (فقط نمایشی) ──
            // صنف شاگرد از حساب/پیشرفت واقعی او می‌آید، نه یک انتخاب دستی؛
            // با ارتقای صنف (بعد از تکمیل نصاب و کامیابی در امتحان) این
            // برچسب و کل برنامهٔ هفتگی خودکار به‌روز می‌شود.
            Row(
              children: [
                Text(context.tr('studyPlan.myGradeLabel'),
                    style: TextStyle(
                        fontSize: 13, color: scheme.onSurfaceVariant)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: Text(context.tr('grade.label', {'grade': '$grade'}),
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimaryContainer)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // ── روزهای هفته ──
            for (final day in plan.days) ...[
              _DayCard(day: day, isToday: day.weekday == DateTime.now().weekday),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _DayCard extends ConsumerWidget {
  final PlanDay day;
  final bool isToday;
  const _DayCard({required this.day, required this.isToday});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: isToday ? scheme.primary : scheme.outlineVariant,
          width: isToday ? 1.6 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(day.nameFa,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
              const SizedBox(width: 8),
              if (isToday)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(context.tr('studyPlan.today'),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (day.isRestDay)
            Text(
              day.weekday == DateTime.friday
                  ? context.tr('studyPlan.holiday')
                  : context.tr('studyPlan.noPlanRecorded'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in day.slots)
                  _SubjectChip(
                    subjectId: slot.subjectId,
                    label: slot.subjectNameFa,
                    minutes: slot.minutes,
                    enabled: isToday,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// چیپ یک مضمون — طبق همان هماهنگیِ زندهٔ نصاب درسی که کارت «امروز» دارد
/// (نگاه کنید به `today_schedule_card.dart`/`openTodaySubjectPointer`):
/// فقط برای امروز (`enabled`) فعال است، و لمسش دقیقاً همان درس/آزمون/
/// کار-خانگیِ نصاب درسی را باز می‌کند — نه لینک ثابت به گفت‌وگوی آزاد.
/// رفع اشکال: قبلاً این چیپ مسیر ناوبری خودش را داشت (همیشه معلم هوشمند
/// آزاد)، کاملاً مستقل از هماهنگ‌سازی‌ای که در کارت «امروز» انجام شده بود —
/// یعنی همان مضمون از این صفحه باز می‌شد بدون رعایت قفل نصاب.
class _SubjectChip extends ConsumerWidget {
  final String subjectId;
  final String label;
  final int minutes;
  final bool enabled;
  const _SubjectChip({
    required this.subjectId,
    required this.label,
    required this.minutes,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subject = mockSubjects.firstWhere((s) => s.id == subjectId,
        orElse: () => mockSubjects.first);
    final color = Color(subject.colorValue);

    // نقطهٔ زنده فقط برای چیپ‌های فعال (امروز) لازم است — چیپ‌های روزهای
    // دیگر اصلاً قابل لمس نیستند، پس نیازی به این Provider ندارند.
    final pointerAsync = enabled ? ref.watch(todaySubjectPointerProvider(subjectId)) : null;
    final pointer = pointerAsync?.valueOrNull;
    final loading = enabled && (pointerAsync?.isLoading ?? false) && pointer == null;

    return ActionChip(
      avatar: loading
          ? SizedBox(
              width: 18,
              height: 18,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            )
          : Icon(Icons.play_circle_fill_rounded,
              size: 18, color: enabled ? color : color.withValues(alpha: .4)),
      label: Text(context.tr('studyPlan.subjectMinutes', {'label': label, 'minutes': '$minutes'})),
      labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: enabled ? null : Theme.of(context).disabledColor),
      backgroundColor: color.withValues(alpha: .08),
      side: BorderSide(color: color.withValues(alpha: .35)),
      onPressed: (enabled && !loading)
          ? () => openTodaySubjectPointer(context, ref, subjectId: subjectId, pointer: pointer)
          : null,
    );
  }
}
