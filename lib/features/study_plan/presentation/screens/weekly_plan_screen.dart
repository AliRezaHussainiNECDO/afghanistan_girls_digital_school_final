import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared_models/subject.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../ai_teacher/presentation/providers/learning_progress_providers.dart';
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
          const SnackBar(content: Text('برنامهٔ نو ساخته شد ✅')));
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
      title: 'تقسیم اوقات هفتگی من',
      role: AppUserRole.student,
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطا: $e')),
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
                              ? 'ساخته‌شده توسط هوش مصنوعی (Ollama)'
                              : 'ساخته‌شده با اولویت‌بندی هوشمند',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text('صنف $grade — هفتهٔ ${plan.weekKey}',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: .9),
                                fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'تولید دوبارهٔ برنامه',
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
                Text('صنف من:',
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
                  child: Text('صنف $grade',
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
  final dynamic day; // PlanDay
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
              Text(day.nameFa as String,
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
                  child: Text('امروز',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: scheme.primary)),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (day.isRestDay as bool)
            Text(
              day.weekday == DateTime.friday
                  ? 'رخصتی — استراحت و مرور آزاد 🌸'
                  : 'برنامه‌ای ثبت نشده',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final slot in day.slots)
                  _SubjectChip(
                    subjectId: slot.subjectId as String,
                    label: slot.subjectNameFa as String,
                    minutes: slot.minutes as int,
                    enabled: isToday,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

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
    return ActionChip(
      avatar: Icon(Icons.play_circle_fill_rounded,
          size: 18, color: enabled ? color : color.withValues(alpha: .4)),
      label: Text('$label · $minutes دقیقه'),
      labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: enabled ? null : Theme.of(context).disabledColor),
      backgroundColor: color.withValues(alpha: .08),
      side: BorderSide(color: color.withValues(alpha: .35)),
      onPressed: enabled
          ? () {
              ref.read(aiTeacherInitialSubjectProvider.notifier).state =
                  subjectId;
              context.push(AppRoutes.aiTeacher);
            }
          : null,
    );
  }
}
