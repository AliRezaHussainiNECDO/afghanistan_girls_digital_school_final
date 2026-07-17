import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/router/app_routes.dart';
import '../../app/theme/design_tokens.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/grade_map/presentation/providers/grade_map_providers.dart';
import '../../features/progression/data/progression_store.dart' show kPromoteExamMark;
import '../../shared_models/subject.dart';
import 'selected_grade_provider.dart';

IconData _iconFor(String icon) {
  switch (icon) {
    case 'calculate':
      return Icons.calculate_rounded;
    case 'science':
      return Icons.science_rounded;
    case 'biotech':
      return Icons.biotech_rounded;
    case 'eco':
      return Icons.eco_rounded;
    case 'language':
      return Icons.language_rounded;
    case 'menu_book':
      return Icons.menu_book_rounded;
    case 'history_edu':
      return Icons.history_edu_rounded;
    case 'public':
      return Icons.public_rounded;
    case 'mosque':
      return Icons.mosque_rounded;
    case 'computer':
      return Icons.computer_rounded;
    default:
      return Icons.school_rounded;
  }
}

/// شناسهٔ شاگرد واردشده — برای واکشی «نصاب درسی» واقعی از سرور.
String _studentId(WidgetRef ref) => ref.watch(authSessionProvider)?.id ?? 'unknown';

/// نوار انتخاب صنف — با منطق قفل: صنف فعال باز است، صنوف بالاتر قفل، و صنوف
/// تکمیل‌شده قابل مرور.
///
/// رفع اشکال هماهنگی: «صنف فعال» قبلاً همیشه از یک انبار محلیِ گوشی
/// (ProgressionStore) خوانده می‌شد، حتی وقتی اپ به Backend واقعی وصل بود —
/// یعنی این نوار می‌توانست صنفی نشان دهد که با `current_grade` واقعیِ
/// دیتابیس هیچ ربطی نداشت. اکنون از `activeGradeProvider` می‌خواند که خودش
/// در حالت Backend واقعی از نشست واقعی کاربر تغذیه می‌شود (بخش
/// `core/student/selected_grade_provider.dart`).
class GradeSelector extends ConsumerWidget {
  const GradeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final current = ref.watch(activeGradeProvider);
    final selected = ref.watch(selectedGradeProvider);
    // اگر انتخاب فعلی قفل شده، به صنف فعال بازگردد.
    final effSelected = selected > current ? current : selected;

    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        itemCount: kStudentGrades.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final g = kStudentGrades[i];
          final locked = g > current;
          final active = g == current;
          final isSel = g == effSelected;

          return GestureDetector(
            onTap: () {
              if (locked) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('صنف $g قفل است — ابتدا صنف فعلی را کامل کن و امتحان بده.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              ref.read(selectedGradeProvider.notifier).select(g);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isSel && !locked ? AppColors.heroGradient : null,
                color: isSel && !locked
                    ? null
                    : (locked ? scheme.surfaceContainerHigh : scheme.surfaceContainerLowest),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(
                    color: isSel && !locked ? Colors.transparent : scheme.outlineVariant),
                boxShadow: isSel && !locked ? AppShadows.warm : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (locked)
                    Icon(Icons.lock_rounded, size: 14, color: scheme.onSurfaceVariant)
                  else if (g < current)
                    Icon(Icons.check_circle_rounded, size: 14, color: isSel ? Colors.white : AppColors.green600),
                  if (locked || g < current) const SizedBox(width: 5),
                  Text(
                    'صنف $g',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: isSel && !locked
                          ? Colors.white
                          : (locked ? scheme.onSurfaceVariant : scheme.onSurface),
                    ),
                  ),
                  if (active) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: (isSel ? Colors.white : AppColors.green600).withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                      child: Text('فعال',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white : AppColors.green600)),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// شبکهٔ مضامین صنف انتخاب‌شده، با نمایش درصد تکمیل هر مضمون.
///
/// رفع اشکال هماهنگی: قبلاً درصد تکمیل از انبار محلیِ گوشی خوانده می‌شد که
/// هرگز با درس‌های واقعاً دیده‌شده روی سرور (همان چیزی که «معلم هوشمند» و
/// نصاب واقعی مدیریت می‌کنند) هماهنگ نبود. اکنون دقیقاً همان منبعِ واحدِ
/// حقیقتی را می‌خواند که صفحهٔ «نقشهٔ صنف» می‌خواند (`gradeMapProvider` →
/// `GET /students/{id}/grade-map`، بخش lib/progress.ts::getSubjectProgressList).
class GradeSubjectsGrid extends ConsumerWidget {
  final bool shrinkWrap;
  const GradeSubjectsGrid({super.key, this.shrinkWrap = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grade = ref.watch(selectedGradeProvider);
    final activeGrade = ref.watch(activeGradeProvider);
    final studentId = _studentId(ref);
    final gradeMapAsync = ref.watch(gradeMapProvider(studentId));

    return gradeMapAsync.when(
      loading: () => const _GridPlaceholder(),
      error: (e, st) => _GridErrorCard(
        onRetry: () => ref.invalidate(gradeMapProvider(studentId)),
      ),
      data: (map) {
        // درصدها فقط برای صنف فعال معتبرند — صنوف قبلی/مرورشده فقط نمایشی‌اند.
        final showCompletion = grade == activeGrade;
        final bySubject = {for (final s in map.subjects) s.subjectId: s};
        return GridView.count(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          padding: EdgeInsets.zero,
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.15,
          children: [
            for (var i = 0; i < mockSubjects.length; i++)
              _SubjectCard(
                subject: mockSubjects[i],
                grade: grade,
                completion: showCompletion ? bySubject[mockSubjects[i].id]?.completionPercent : null,
              ).animate().fadeIn(delay: (25 * i).ms, duration: 220.ms).slideY(begin: 0.08),
          ],
        );
      },
    );
  }
}

class _GridPlaceholder extends StatelessWidget {
  const _GridPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 160,
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.primary),
      ),
    );
  }
}

class _GridErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _GridErrorCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: scheme.error),
          const SizedBox(width: 10),
          const Expanded(child: Text('بارگذاری مضامین ناکام شد', style: TextStyle(fontSize: 13))),
          TextButton(onPressed: onRetry, child: const Text('تلاش دوباره')),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatelessWidget {
  final Subject subject;
  final int grade;
  final double? completion;
  const _SubjectCard({required this.subject, required this.grade, this.completion});

  @override
  Widget build(BuildContext context) {
    final color = Color(subject.colorValue);
    final done = (completion ?? 0) >= 100;
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => context.push(AppRoutes.curriculumChapters(subject.id)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  if (completion != null)
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: (completion! / 100).clamp(0, 1),
                        strokeWidth: 4,
                        backgroundColor: color.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(done ? AppColors.green600 : color),
                      ),
                    ),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.18), shape: BoxShape.circle),
                    child: Icon(_iconFor(subject.icon), size: 20, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(subject.nameFa,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(
                completion == null ? 'صنف $grade' : '${completion!.toStringAsFixed(0)}٪',
                style: TextStyle(fontSize: 10.5, color: done ? AppColors.green600 : color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// کارت «وضعیت ارتقا» — درصد تکمیل، وضعیت امتحان و شرایط باز شدن صنف بعدی.
///
/// رفع اشکال هماهنگی: همهٔ این اعداد اکنون از همان پاسخ سرور
/// (`gradeMapProvider`) می‌آیند که «نقشهٔ صنف» و نصاب درسی هم از آن
/// استفاده می‌کنند — نه از یک شبیه‌سازی محلی که هرگز روی دیتابیس واقعی
/// اثر نمی‌گذاشت.
class PromotionStatusCard extends ConsumerWidget {
  const PromotionStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final studentId = _studentId(ref);
    final gradeMapAsync = ref.watch(gradeMapProvider(studentId));

    return gradeMapAsync.when(
      loading: () => Container(
        height: 140,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.primary),
      ),
      error: (e, st) => _GridErrorCard(onRetry: () => ref.invalidate(gradeMapProvider(studentId))),
      data: (map) {
        final overall = map.gradeAveragePercent;
        final completedCount = map.subjects.where((s) => s.completionPercent >= 100).length;
        final totalCount = map.subjects.isEmpty ? mockSubjects.length : map.subjects.length;
        final atTop = map.gradeNumber >= 12;
        final canPromote = map.canPromote;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.trending_up_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('وضعیت ارتقا — صنف ${map.gradeNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('$completedCount از $totalCount مضمون تکمیل شده',
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ]),
                ),
                Text('${overall.toStringAsFixed(0)}٪',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: AppColors.orange600)),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: (overall / 100).clamp(0, 1),
                  minHeight: 9,
                  backgroundColor: scheme.surfaceContainerHigh,
                  valueColor: const AlwaysStoppedAnimation(AppColors.orange600),
                ),
              ),
              const SizedBox(height: 14),
              _req(context, 'تکمیل تمام مضامین (۱۰۰٪)', map.allSubjectsComplete),
              const SizedBox(height: 8),
              _req(
                  context,
                  'کامیابی در امتحان (${map.examBestScore != null ? '${map.examBestScore!.toStringAsFixed(0)}٪' : 'نداده'} از ${kPromoteExamMark.toStringAsFixed(0)}٪)',
                  map.examPassed),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (atTop ? AppColors.green600 : (canPromote ? AppColors.green600 : AppColors.gold600))
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(children: [
                  Icon(atTop ? Icons.emoji_events_rounded : (canPromote ? Icons.celebration_rounded : Icons.info_outline_rounded),
                      size: 18,
                      color: atTop ? AppColors.green600 : (canPromote ? AppColors.green600 : AppColors.gold600)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      atTop
                          ? 'تبریک! تو در بالاترین صنف (۱۲) هستی. 🎓'
                          : (canPromote
                              ? 'آفرین! آمادهٔ ارتقا به صنف ${map.gradeNumber + 1} هستی.'
                              : 'برای باز شدن صنف ${map.gradeNumber + 1}، مضامین را کامل کن و امتحان بده.'),
                      style: const TextStyle(fontSize: 12, height: 1.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _req(BuildContext context, String label, bool done) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          size: 18, color: done ? AppColors.green600 : scheme.onSurfaceVariant),
      const SizedBox(width: 8),
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
    ]);
  }
}
