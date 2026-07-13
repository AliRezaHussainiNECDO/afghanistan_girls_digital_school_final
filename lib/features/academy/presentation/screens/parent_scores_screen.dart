import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../parent_dashboard/domain/entities/parent_entities.dart';
import '../../../parent_dashboard/presentation/providers/parent_providers.dart';
import '../../domain/academy_entities.dart';
import '../academy_providers.dart';
import 'child_exam_scores_screen.dart';

/// نمرات فرزندان (نمای والد).
///
/// گام ۱: لیست فرزندانِ لینک‌شده با معلومات هر
/// فرزند؛ با کلیک روی هر کارت، تمام نمرات امتحانات همان فرزند (گام ۲) باز
/// می‌شود.
///
/// همگامی با منطق امتحانات شاگرد: فرزندان از `linkedChildrenProvider`
/// (بخش ۱۳ب سند — فقط فرزندان تأییدشدهٔ همین والد) و نمرات از
/// `submissionsByStudentProvider` می‌آیند — دقیقاً همان `AcademyStore` که
/// صفحهٔ امتحانات شاگرد (`ExamsScreen`) نتایج را در آن ثبت می‌کند. بنابراین
/// هر چه شاگرد می‌بیند، والد هم همان را می‌بیند.
class ParentScoresScreen extends ConsumerWidget {
  const ParentScoresScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final childrenAsync = ref.watch(linkedChildrenProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: 'نمرات فرزندان',
      role: AppUserRole.parent,
      body: childrenAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (children) {
          if (children.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.family_restroom_rounded,
                      size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('هنوز فرزندی به حساب شما لینک نشده است.\nاز داشبورد والدین کد دعوت فرزندتان را وارد کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant, height: 1.8)),
                ]),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('فرزند خود را انتخاب کنید تا تمام نمرات امتحاناتش را ببینید',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant))
                  .animate()
                  .fadeIn(duration: 240.ms),
              const SizedBox(height: 12),
              for (var i = 0; i < children.length; i++)
                _ChildCard(child: children[i])
                    .animate()
                    .fadeIn(delay: (70 * i).ms, duration: 280.ms)
                    .slideY(begin: 0.08, curve: Curves.easeOutCubic),
            ],
          );
        },
      ),
    );
  }
}

/// کارت معلومات یک فرزند: نام، صنف فعلی، حاضری + آمار زندهٔ امتحانات
/// (تعداد، میانگین، قبولی) که از همان submissions شاگرد محاسبه می‌شود.
class _ChildCard extends ConsumerWidget {
  final LinkedChild child;
  const _ChildCard({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final summaryAsync = ref.watch(childSummaryProvider(child.studentId));
    final subsAsync = ref.watch(submissionsByStudentProvider(child.studentId));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.xl),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ChildExamScoresScreen(
              studentId: child.studentId,
              displayName: child.displayName,
            ),
          )),
          child: Column(
            children: [
              // ── هدر: هویت فرزند ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
                ),
                child: Row(children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      child.displayName.isEmpty ? '?' : child.displayName.substring(0, 1),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.displayName,
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 4),
                        summaryAsync.maybeWhen(
                          data: (s) => Row(children: [
                            _heroChip(Icons.school_rounded, 'صنف ${s.gradeNumber}'),
                            const SizedBox(width: 6),
                            _heroChip(Icons.event_available_rounded,
                                'حاضری ${s.attendanceRatePercent.toStringAsFixed(0)}٪'),
                          ]),
                          orElse: () => Text('در حال بارگذاری…',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85), fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                ]),
              ),
              // ── آمار زندهٔ امتحانات ──
              Padding(
                padding: const EdgeInsets.all(14),
                child: subsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(8),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  ),
                  error: (e, st) => Text(e.toString(),
                      style: TextStyle(color: scheme.error, fontSize: 12)),
                  data: (subs) => _statsRow(context, subs),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: Colors.white),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _statsRow(BuildContext context, List<Submission> subs) {
    final scheme = Theme.of(context).colorScheme;
    if (subs.isEmpty) {
      return Row(children: [
        Icon(Icons.hourglass_empty_rounded, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text('هنوز امتحانی ثبت نشده است',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
        ),
      ]);
    }
    final avg = subs.fold<double>(0, (s, x) => s + x.scorePercent) / subs.length;
    final passed = subs.where((s) => s.passed).length;
    final avgColor = avg >= 50 ? AppColors.green600 : AppColors.orange600;
    return Row(children: [
      _stat(context, Icons.assignment_turned_in_rounded, '${subs.length}', 'امتحان', scheme.primary),
      _divider(scheme),
      _stat(context, Icons.speed_rounded, '${avg.toStringAsFixed(0)}٪', 'میانگین', avgColor),
      _divider(scheme),
      _stat(context, Icons.verified_rounded, '$passed', 'قبولی', AppColors.green600),
    ]);
  }

  Widget _divider(ColorScheme scheme) =>
      Container(width: 1, height: 34, color: scheme.outlineVariant);

  Widget _stat(BuildContext context, IconData icon, String value, String label, Color color) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 5),
          Text(value,
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
        ]),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}
