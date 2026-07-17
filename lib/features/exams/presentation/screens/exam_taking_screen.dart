import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../../shared_models/app_notification.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../grade_map/presentation/providers/grade_map_providers.dart';
import '../../domain/entities/exam_entities.dart';
import '../../domain/usecases/exams_usecases.dart';
import '../providers/exams_providers.dart';

/// State Machine بخش ۷.۴ سند (نسخهٔ ساده‌شدهٔ فاز ۱، بدون Offline/Disconnect
/// Recovery که در بخش ۲۲ پیاده می‌شود): IN_PROGRESS -> SUBMITTED -> GRADED.
class ExamTakingScreen extends ConsumerStatefulWidget {
  final String examId;
  const ExamTakingScreen({super.key, required this.examId});

  @override
  ConsumerState<ExamTakingScreen> createState() => _ExamTakingScreenState();
}

class _ExamTakingScreenState extends ConsumerState<ExamTakingScreen> {
  final Map<String, int> _answers = {};
  bool _submitting = false;
  ExamResult? _result;

  Future<void> _submit(List<ExamQuestion> questions) async {
    setState(() => _submitting = true);
    final result = await ref
        .read(submitAnswersUseCaseProvider)
        .call(SubmitAnswersParams(examId: widget.examId, answers: _answers));
    setState(() {
      _submitting = false;
      _result = result.fold((f) => null, (r) => r);
    });
    if (mounted && _result != null && _result!.scorePercent >= 50) {
      CelebrationOverlay.of(context)?.burst();
    }

    // رفع اشکال ارتقای صنف: این امتحان یک امتحان «نهایی» واقعی بود و سرور
    // ارتقا را بلافاصله روی دیتابیس اعمال کرد (بخش
    // lib/progress.ts::promoteIfEligible) — نشست کاربر و نصاب درسی را
    // بدون نیاز به ورود مجدد به‌روز می‌کنیم تا همه‌جا هماهنگ باشد.
    final r = _result;
    if (r != null && r.promoted && r.newGrade != null) {
      ref.read(authSessionProvider.notifier).updateCurrentGrade(r.newGrade!);
      ref.read(selectedGradeProvider.notifier).select(r.newGrade!);
      final studentId = ref.read(authSessionProvider)?.id;
      if (studentId != null) ref.invalidate(gradeMapProvider(studentId));
      NotificationCenter.instance.push(
        title: 'ارتقا به صنف بعدی 🎓',
        body: 'تبریک! تمام مضامین را کامل کردی و امتحان نهایی را کامیاب شدی — به صنف ${r.newGrade} ارتقا یافتی.',
        kind: NotificationKind.grade,
        priority: NotificationPriority.high,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(examQuestionsProvider(widget.examId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('exams.start'))),
      body: questionsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (questions) {
          if (_result != null) {
            return _ResultView(result: _result!);
          }
          return Column(
            children: [
              LinearProgressIndicator(
                value: questions.isEmpty ? 0 : _answers.length / questions.length,
                minHeight: 4,
                backgroundColor: scheme.surfaceContainerHigh,
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: questions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final q = questions[i];
                    final answered = _answers.containsKey(q.id);
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        border: Border.all(
                          color: answered ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant,
                        ),
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
                                decoration: BoxDecoration(
                                  color: answered ? scheme.primary : scheme.surfaceContainerHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text('${i + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: answered ? Colors.white : scheme.onSurfaceVariant,
                                      )),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  q.text,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ...List.generate(q.options.length, (optIndex) {
                            final selected = _answers[q.id] == optIndex;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Material(
                                color: selected ? scheme.primaryContainer : scheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                  onTap: () => setState(() => _answers[q.id] = optIndex),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Icon(
                                          selected
                                              ? Icons.radio_button_checked_rounded
                                              : Icons.radio_button_unchecked_rounded,
                                          size: 18,
                                          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            q.options[optIndex],
                                            style: TextStyle(
                                              color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                                              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AppPrimaryButton(
                    label: context.tr('exams.submit'),
                    loading: _submitting,
                    onPressed: questions.isEmpty || _answers.length < questions.length
                        ? null
                        : () => _submit(questions),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ExamResult result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passed = result.scorePercent >= 50;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: (passed ? scheme.primary : scheme.error).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                passed ? Icons.emoji_events_rounded : Icons.sentiment_neutral_rounded,
                size: 48,
                color: passed ? scheme.primary : scheme.error,
              ),
            ).animate().scale(
                begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 420.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 20),
            Text(
              '${result.scorePercent.toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
            ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
            const SizedBox(height: 8),
            Text(
              'پاسخ‌های درست: ${result.correctCount}/${result.totalCount}',
              style: TextStyle(color: scheme.onSurfaceVariant),
            ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
            const SizedBox(height: 28),
            AppPrimaryButton(
              label: context.tr('common.back'),
              onPressed: () => context.go(AppRoutes.exams),
            ),
          ],
        ),
      ),
    );
  }
}
