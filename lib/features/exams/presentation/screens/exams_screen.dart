import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../academy/domain/academy_entities.dart';
import '../../../academy/presentation/academy_providers.dart';
import '../../../academy/presentation/screens/academy_exam_screen.dart';
import '../../../academy/presentation/widgets/academy_shared.dart';
import '../../domain/entities/exam_entities.dart';
import '../providers/exams_providers.dart';

/// امتحانات شاگرد — رفع اشکال ریشه‌ای مهم: این صفحه قبلاً **فقط** امتحانات
/// تمرینیِ «آکادمی» (بر اساس بانک سؤال) را نشان می‌داد و هرگز امتحانات
/// واقعیِ سرور (`/exams/available`) را نمی‌خواند. در نتیجه صفحهٔ
/// `ExamTakingScreen` و کل مسیر ارتقای واقعی صنف (که فقط با کامیابی در
/// امتحان «نهایی» و از طریق `POST /exams/:id/submit` روی سرور فعال می‌شود)
/// برای هیچ شاگردی در عمل قابل‌دسترس نبود — حتی وقتی مدیر امتحان نهایی را
/// می‌ساخت و منتشر می‌کرد. اکنون این صفحه هر دو نوع را روشن و جدا نشان
/// می‌دهد: «امتحان نهایی صنف» (دروازهٔ واقعی ارتقا) + امتحانات رسمیِ دیگر
/// (کوییز/کارخانگی/ماهانه) در بالا، و «تمرین مضامین» (آکادمی) پایین‌تر.
class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final officialAsync = ref.watch(availableExamsProvider);
    final practiceAsync = ref.watch(studentExamsProvider);
    final mine = ref.watch(mySubmissionsProvider);

    return AppScaffold(
      title: context.tr('exams.available'),
      role: AppUserRole.student,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(availableExamsProvider);
          ref.invalidate(studentExamsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            officialAsync.when(
              loading: () => const _SectionLoading(),
              error: (e, st) => ErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(availableExamsProvider),
              ),
              data: (exams) => _OfficialExamsSection(exams: exams),
            ),
            const SizedBox(height: 22),
            mine.maybeWhen(
              data: (subs) => subs.isEmpty ? const SizedBox.shrink() : _recentPracticeResults(context, subs),
              orElse: () => const SizedBox.shrink(),
            ),
            Row(
              children: [
                Icon(Icons.fitness_center_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(context.tr('exams.subjectPractice'),
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15, color: Theme.of(context).colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              context.tr('exams.practiceNote'),
              style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            practiceAsync.when(
              loading: () => const _SectionLoading(),
              error: (e, st) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(studentExamsProvider),
                  ),
              data: (exams) => _PracticeExamsSection(exams: exams),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recentPracticeResults(BuildContext context, List<Submission> subs) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('exams.recentPracticeResults'), style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
          const SizedBox(height: 8),
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: subs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final s = subs[i];
                final color = s.passed ? AppColors.green600 : AppColors.orange600;
                return Container(
                  width: 130,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: color.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${s.scorePercent.toStringAsFixed(0)}٪',
                          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: color)),
                      Text('${s.subject} · ${s.gradeLabel}',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingView(),
      );
}

// ═══════════════════════ امتحانات رسمی (سرور — دروازهٔ ارتقا) ═══════════════
class _OfficialExamsSection extends StatelessWidget {
  final List<ExamSummary> exams;
  const _OfficialExamsSection({required this.exams});

  @override
  Widget build(BuildContext context) {
    final finalExam = exams.where((e) => e.isFinal).toList();
    final others = exams.where((e) => !e.isFinal).toList();

    if (exams.isEmpty) {
      return _NoFinalExamCard();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (finalExam.isEmpty)
          _NoFinalExamCard()
        else
          ...finalExam.map(
            (e) => _FinalExamHero(exam: e).animate().fadeIn(duration: 320.ms).slideY(begin: -0.05),
          ),
        if (others.isNotEmpty) ...[
          const SizedBox(height: 18),
          Row(
            children: [
              Icon(Icons.verified_rounded, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(context.tr('exams.otherOfficialExams'),
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Theme.of(context).colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 10),
          ...others.asMap().entries.map((entry) {
            final e = entry.value;
            return _OfficialExamCard(exam: e)
                .animate()
                .fadeIn(delay: (40 * entry.key).ms, duration: 240.ms)
                .slideY(begin: 0.06);
          }),
        ],
      ],
    );
  }
}

class _NoFinalExamCard extends StatelessWidget {
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
          Icon(Icons.hourglass_empty_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.tr('exams.finalExamNotPublished'),
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalExamHero extends StatelessWidget {
  final ExamSummary exam;
  const _FinalExamHero({required this.exam});

  @override
  Widget build(BuildContext context) {
    final passed = exam.passed;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: passed ? AppColors.successGradient : AppColors.goldCelebrationGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                child: Icon(passed ? Icons.emoji_events_rounded : Icons.workspace_premium_rounded,
                    color: Colors.white, size: 28),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                  begin: 1.0, end: 1.07, duration: 1500.ms, curve: Curves.easeInOut),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('exams.gradeFinalExam'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(
                        context.tr('exams.summaryLine', {
                          'subject': exam.subjectNameFa,
                          'count': '${exam.questionCount}',
                          'duration': '${exam.durationMinutes}',
                        }),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (exam.attempted) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Row(
                children: [
                  Icon(passed ? Icons.check_circle_rounded : Icons.info_outline_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      passed
                          ? context.tr('exams.passedBestScore',
                              {'score': exam.bestScorePercent!.toStringAsFixed(0)})
                          : context.tr('exams.failedBestScore', {
                              'score': exam.bestScorePercent!.toStringAsFixed(0),
                              'passMark': '80',
                            }),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: passed ? AppColors.green700 : AppColors.orange700,
              ),
              onPressed: () => context.push(AppRoutes.examTaking(exam.id)),
              icon: Icon(passed ? Icons.replay_rounded : Icons.play_arrow_rounded),
              label: Text(passed ? context.tr('exams.retryForBetterScore') : context.tr('exams.startFinalExam')),
            ),
          ),
        ],
      ),
    );
  }
}

class _OfficialExamCard extends StatelessWidget {
  final ExamSummary exam;
  const _OfficialExamCard({required this.exam});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
            child: Icon(_iconFor(exam.type), color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${exam.subjectNameFa} · ${_typeLabel(context, exam.type)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  exam.attempted
                      ? context.tr('exams.bestScoreQuestions', {
                          'score': exam.bestScorePercent!.toStringAsFixed(0),
                          'count': '${exam.questionCount}',
                        })
                      : context.tr('exams.questionsAndDuration',
                          {'count': '${exam.questionCount}', 'duration': '${exam.durationMinutes}'}),
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed: () => context.push(AppRoutes.examTaking(exam.id)),
            child: Text(exam.attempted ? context.tr('exams.retry') : context.tr('exams.start')),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ExamType t) {
    switch (t) {
      case ExamType.dailyQuiz:
        return Icons.bolt_rounded;
      case ExamType.homework:
        return Icons.home_work_rounded;
      case ExamType.monthly:
        return Icons.calendar_month_rounded;
      case ExamType.finalExam:
        return Icons.workspace_premium_rounded;
    }
  }

  String _typeLabel(BuildContext context, ExamType t) {
    switch (t) {
      case ExamType.dailyQuiz:
        return context.tr('exams.dailyQuiz');
      case ExamType.homework:
        return context.tr('exams.homework');
      case ExamType.monthly:
        return context.tr('exams.monthly');
      case ExamType.finalExam:
        return context.tr('exams.finalExam');
    }
  }
}

// ═══════════════════════════ تمرین مضامین (آکادمی) ═══════════════════════════
class _PracticeExamsSection extends StatelessWidget {
  final List<SubjectExam> exams;
  const _PracticeExamsSection({required this.exams});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (exams.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.assignment_outlined, color: scheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Expanded(
              child: Text(context.tr('exams.noPracticeYet'),
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }
    final byGrade = <int, List<SubjectExam>>{};
    for (final e in exams) {
      byGrade.putIfAbsent(e.gradeId, () => []).add(e);
    }
    final grades = byGrade.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final g in grades) ...[
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Text(gradeLabel(context, g),
                style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant, fontSize: 12.5)),
          ),
          ...byGrade[g]!.asMap().entries.map((entry) {
            final exam = entry.value;
            return _PracticeExamCard(
              exam: exam,
              onStart: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AcademyExamScreen(subject: exam.subject, gradeId: exam.gradeId),
              )),
            ).animate().fadeIn(delay: (30 * entry.key).ms, duration: 220.ms).slideY(begin: 0.05);
          }),
        ],
      ],
    );
  }
}

class _PracticeExamCard extends StatelessWidget {
  final SubjectExam exam;
  final VoidCallback onStart;
  const _PracticeExamCard({required this.exam, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.fitness_center_rounded, color: scheme.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(context.tr('exams.questionsAndPoints',
                        {'count': '${exam.questionCount}', 'points': '${exam.totalPoints}'}),
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onStart, child: Text(context.tr('exams.practiceNow'))),
        ],
      ),
    );
  }
}
