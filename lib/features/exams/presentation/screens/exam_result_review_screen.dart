import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../academy/presentation/widgets/academy_shared.dart' show gradeLabel, formatDate;
import '../../domain/entities/exam_entities.dart';
import '../providers/exams_providers.dart';

/// صفحهٔ «مرور پاسخ‌ها» — بعد از دادن هر امتحان رسمی (کوییز/کارخانگی/ماهانه/
/// نهایی)، شاگرد (یا والدِ لینک‌شده/مدیر) می‌تواند دقیقاً ببیند به هر سؤال
/// چه پاسخی داده، آیا درست بوده یا غلط، و در صورت غلط‌بودن، پاسخ درست چه
/// بوده. طبق درخواست کاربر: طراحی مدرن، پویا و جذاب — با گرادیان، حرکت
/// نرم برای هر سؤال، و رنگ‌بندی واضح سبز/قرمز.
class ExamResultReviewScreen extends ConsumerWidget {
  final String attemptId;
  const ExamResultReviewScreen({super.key, required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(examAttemptReviewProvider(attemptId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('exams.reviewTitle'))),
      body: reviewAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(examAttemptReviewProvider(attemptId)),
        ),
        data: (review) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _ReviewHero(review: review).animate().fadeIn(duration: 320.ms).slideY(begin: -0.06),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.fact_check_rounded, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(context.tr('exams.yourAnswers'),
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: scheme.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < review.questions.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ReviewQuestionCard(index: i + 1, question: review.questions[i])
                    .animate()
                    .fadeIn(delay: (50 * i).ms, duration: 260.ms)
                    .slideY(begin: 0.08, curve: Curves.easeOutCubic),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReviewHero extends StatelessWidget {
  final ExamAttemptReview review;
  const _ReviewHero({required this.review});

  @override
  Widget build(BuildContext context) {
    final passed = review.passed;
    return Container(
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
                width: 60,
                height: 60,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  '${review.scorePercent.toStringAsFixed(0)}٪',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(
                  begin: 1.0, end: 1.06, duration: 1600.ms, curve: Curves.easeInOut),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.examTitle.isNotEmpty ? review.examTitle : review.subjectNameFa,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 4),
                    Text(
                      '${review.subjectNameFa} · ${gradeLabel(context, review.gradeNumber)} · ${formatDate(review.submittedAt)}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
                Text(
                  context.tr('exams.correctAnswersCount',
                      {'correct': '${review.correctCount}', 'total': '${review.totalCount}'}),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final int index;
  final ExamReviewQuestion question;
  const _ReviewQuestionCard({required this.index, required this.question});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final correct = question.isCorrect;
    final statusColor = correct == null
        ? AppColors.gold600
        : correct
            ? AppColors.green600
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: statusColor.withValues(alpha: 0.35)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(color: scheme.surfaceContainerHigh, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('$index',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(question.text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      correct == null
                          ? Icons.hourglass_top_rounded
                          : correct
                              ? Icons.check_rounded
                              : Icons.close_rounded,
                      size: 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      correct == null
                          ? context.tr('exams.pendingReview')
                          : correct
                              ? context.tr('exams.correctBadge')
                              : context.tr('exams.wrongBadge'),
                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (question.isEssay)
            _EssayReview(question: question)
          else
            _ChoicesReview(question: question),
        ],
      ),
    );
  }
}

/// مرور سؤال چهارگزینه‌ای/صحیح‌وغلط — گزینهٔ درست همیشه سبز؛ اگر شاگرد گزینهٔ
/// دیگری زده بود، همان گزینه قرمز مشخص می‌شود.
class _ChoicesReview extends StatelessWidget {
  final ExamReviewQuestion question;
  const _ChoicesReview({required this.question});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (question.wasSkipped) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Row(
          children: [
            Icon(Icons.remove_circle_outline_rounded, size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.tr('exams.unanswered'),
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
            ),
          ],
        ),
      );
    }
    return Column(
      children: List.generate(question.options.length, (i) {
        final isCorrectOption = i == question.correctIndex;
        final isStudentPick = i == question.studentAnswerIndex;
        Color bg = scheme.surfaceContainerHigh;
        Color fg = scheme.onSurface;
        IconData? icon;
        if (isCorrectOption) {
          bg = AppColors.green600.withValues(alpha: 0.14);
          fg = AppColors.green700;
          icon = Icons.check_circle_rounded;
        } else if (isStudentPick) {
          bg = AppColors.danger.withValues(alpha: 0.12);
          fg = AppColors.danger;
          icon = Icons.cancel_rounded;
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.md)),
            child: Row(
              children: [
                Icon(icon ?? Icons.circle_outlined, size: 17, color: icon != null ? fg : scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(question.options[i],
                      style: TextStyle(color: fg, fontWeight: icon != null ? FontWeight.w700 : FontWeight.w400)),
                ),
                if (isStudentPick && !isCorrectOption)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Text(context.tr('exams.yourAnswerBadge'),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg)),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

/// مرور سؤال تشریحی — پاسخ نوشته‌شدهٔ شاگرد + بازخورد/نمرهٔ AI (در صورت وجود).
class _EssayReview extends StatelessWidget {
  final ExamReviewQuestion question;
  const _EssayReview({required this.question});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Text(
            question.studentAnswerText.isNotEmpty
                ? question.studentAnswerText
                : context.tr('exams.unanswered'),
            style: TextStyle(
                fontSize: 13, height: 1.6, color: question.studentAnswerText.isNotEmpty ? scheme.onSurface : scheme.onSurfaceVariant),
          ),
        ),
        if (question.essayFeedback.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.info),
              const SizedBox(width: 6),
              Expanded(
                child: Text(question.essayFeedback,
                    style: const TextStyle(fontSize: 12, color: AppColors.info, height: 1.5)),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
