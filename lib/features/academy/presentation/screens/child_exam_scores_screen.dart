import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/academy_entities.dart';
import '../academy_providers.dart';
import '../widgets/academy_shared.dart';

/// گام ۲ — تمام نمرات امتحانات یک فرزند، به‌تفکیک صنف ← مضمون ← نوبت.
///
/// همگام با منطق امتحانات شاگرد (بخش ۷ سند):
/// * منبع داده همان `submissionsByStudentProvider`/`AcademyStore` است که
///   شاگرد نتایجش را در آن ثبت می‌کند — نه یک محاسبهٔ جداگانه.
/// * معیار قبولی همان `Submission.passed` (≥ ۵۰٪، بخش ۶.۲) است.
/// * چون هر Submission صنفِ زمانِ امتحان (`gradeId`) را نگه می‌دارد، پس از
///   ارتقای فرزند به صنف بالاتر، نمرات صنف جدید خودبه‌خود به‌عنوان یک بخش
///   جدید در بالای همین صفحه ظاهر می‌شوند و نمرات صنوف قبلی حفظ می‌مانند.
/// * طبق تصمیم سطح دسترسی: همهٔ امتحان‌ها نمایش داده می‌شوند ولی بدون
///   جزئیات تک‌تک سؤالات/پاسخ‌ها (بخش ۱۳ب.۳ — Aggregate-level).
class ChildExamScoresScreen extends ConsumerWidget {
  final String studentId;
  final String displayName;
  const ChildExamScoresScreen({super.key, required this.studentId, required this.displayName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(submissionsByStudentProvider(studentId));
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('academy.scoresForName', {'name': displayName}),
      role: AppUserRole.parent,
      body: subsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
        data: (subs) {
          if (subs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.assignment_outlined,
                      size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(context.tr('academy.childNoExamsYet', {'name': displayName}),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ]),
              ),
            );
          }

          // صنف ← مضمون ← نوبت‌ها (جدیدترین نوبت اول).
          final byGrade = <int, Map<String, List<Submission>>>{};
          for (final s in subs) {
            byGrade
                .putIfAbsent(s.gradeId, () => {})
                .putIfAbsent(s.subject, () => [])
                .add(s);
          }
          // صنف فعلی (بالاترین) اول؛ صنوف قبلی به‌عنوان کارنامهٔ گذشته پایین‌تر.
          final grades = byGrade.keys.toList()..sort((a, b) => b.compareTo(a));

          var delay = 0;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            children: [
              _OverallHeader(displayName: displayName, subs: subs)
                  .animate()
                  .fadeIn(duration: 300.ms)
                  .slideY(begin: 0.06, curve: Curves.easeOutCubic),
              const SizedBox(height: 18),
              for (final g in grades) ...[
                _GradeHeader(gradeId: g, isCurrent: g == grades.first)
                    .animate()
                    .fadeIn(delay: (60 * delay++).ms, duration: 260.ms),
                for (final subject in (byGrade[g]!.keys.toList()..sort()))
                  _SubjectCard(subject: subject, attempts: byGrade[g]![subject]!)
                      .animate()
                      .fadeIn(delay: (60 * delay++).ms, duration: 260.ms)
                      .slideY(begin: 0.06, curve: Curves.easeOutCubic),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// هدر خلاصهٔ کلی: میانگین، تعداد امتحان، قبولی/ناکامی + حلقهٔ پیشرفت.
class _OverallHeader extends StatelessWidget {
  final String displayName;
  final List<Submission> subs;
  const _OverallHeader({required this.displayName, required this.subs});

  @override
  Widget build(BuildContext context) {
    final avg = subs.fold<double>(0, (s, x) => s + x.scorePercent) / subs.length;
    final passed = subs.where((s) => s.passed).length;
    final failed = subs.length - passed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.soft,
      ),
      child: Row(children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('academy.transcriptTitle', {'name': displayName}),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              Row(children: [
                _pill(Icons.assignment_turned_in_rounded,
                    context.tr('academy.examsCountChip', {'count': '${subs.length}'})),
                const SizedBox(width: 6),
                _pill(Icons.check_circle_rounded,
                    context.tr('academy.passedCountChip', {'count': '$passed'})),
              ]),
              if (failed > 0) ...[
                const SizedBox(height: 6),
                _pill(Icons.refresh_rounded,
                    context.tr('academy.failedNeedsRetryChip', {'count': '$failed'})),
              ],
            ],
          ),
        ),
        SizedBox(
          width: 76,
          height: 76,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 76,
              height: 76,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (avg / 100).clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 900),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 7,
                  strokeCap: StrokeCap.round,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${avg.toStringAsFixed(0)}٪',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              Text(context.tr('academy.averageLabel'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 9.5)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
}

/// سرصفحهٔ یک صنف — صنف فعلی نشان «صنف فعلی» می‌گیرد.
class _GradeHeader extends StatelessWidget {
  final int gradeId;
  final bool isCurrent;
  const _GradeHeader({required this.gradeId, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            gradient: isCurrent ? AppColors.successGradient : null,
            color: isCurrent ? null : scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(gradeLabel(context, gradeId),
              style: TextStyle(
                  color: isCurrent ? Colors.white : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5)),
        ),
        if (isCurrent) ...[
          const SizedBox(width: 8),
          Text(context.tr('academy.currentGradeBadge'),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.green600, fontWeight: FontWeight.w700)),
        ],
        const SizedBox(width: 10),
        Expanded(child: Divider(color: scheme.outlineVariant)),
      ]),
    );
  }
}

/// کارت یک مضمون: آخرین نمره + نوار پیشرفت؛ با باز کردن، تاریخچهٔ تمام
/// نوبت‌های امتحان همان مضمون (بدون جزئیات سؤالات) دیده می‌شود.
class _SubjectCard extends StatelessWidget {
  final String subject;
  final List<Submission> attempts; // از Provider مرتب‌شده: جدیدترین اول
  const _SubjectCard({required this.subject, required this.attempts});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final latest = attempts.first;
    final color = latest.passed ? AppColors.green600 : AppColors.orange600;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text('${latest.scorePercent.toStringAsFixed(0)}٪',
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12.5)),
          ),
          title: Text(subject, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (latest.scorePercent / 100).clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 7,
                      backgroundColor: scheme.surfaceContainerHigh,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  context.tr('academy.attemptsCountAndLast',
                      {'count': '${attempts.length}', 'date': formatDate(latest.submittedAt)}),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          children: [
            for (var i = 0; i < attempts.length; i++)
              _AttemptRow(attempt: attempts[i], number: attempts.length - i),
          ],
        ),
      ),
    );
  }
}

/// یک نوبت امتحان: شماره نوبت، تاریخ، امتیاز کسب‌شده، نتیجه — بدون جزئیات
/// تک‌تک سؤالات (بخش ۱۳ب.۳).
class _AttemptRow extends StatelessWidget {
  final Submission attempt;
  final int number;
  const _AttemptRow({required this.attempt, required this.number});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = attempt.passed ? AppColors.green600 : AppColors.orange600;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: color.withValues(alpha: 0.14),
          child: Text('$number',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text(context.tr('academy.attemptNumber', {'number': '$number'}),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                if (attempt.aiAssisted) ...[
                  const SizedBox(width: 6),
                  Icon(Icons.auto_awesome_rounded, size: 12, color: scheme.tertiary),
                  const SizedBox(width: 2),
                  Text(context.tr('academy.aiScoredBadge'),
                      style: TextStyle(fontSize: 10, color: scheme.tertiary)),
                ],
              ]),
              const SizedBox(height: 2),
              Text(
                context.tr('academy.attemptDateAndPoints', {
                  'date': formatDate(attempt.submittedAt),
                  'earned': attempt.earnedPoints.toStringAsFixed(
                      attempt.earnedPoints.truncateToDouble() == attempt.earnedPoints ? 0 : 1),
                  'total': attempt.totalPoints.toStringAsFixed(0),
                }),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${attempt.scorePercent.toStringAsFixed(0)}٪',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: color)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
                attempt.passed ? context.tr('academy.passedShort') : context.tr('academy.failedShort'),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
          ),
        ]),
      ]),
    );
  }
}
