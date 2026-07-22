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
import '../../../student_dashboard/presentation/providers/dashboard_providers.dart';
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

  /// پاسخ متنی سؤالات تشریحی (migration 0030) — نمره‌دهی AI سمت سرور.
  final Map<String, TextEditingController> _essayCtrls = {};
  bool _submitting = false;
  ExamResult? _result;

  TextEditingController _essayCtrl(String qid) =>
      _essayCtrls.putIfAbsent(qid, () => TextEditingController());

  bool _isAnswered(ExamQuestion q) => q.isEssay
      ? (_essayCtrls[q.id]?.text.trim().isNotEmpty ?? false)
      : _answers.containsKey(q.id);

  int _answeredCount(List<ExamQuestion> questions) => questions.where(_isAnswered).length;

  @override
  void dispose() {
    for (final c in _essayCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(List<ExamQuestion> questions) async {
    setState(() => _submitting = true);
    final textAnswers = <String, String>{
      for (final e in _essayCtrls.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    final result = await ref
        .read(submitAnswersUseCaseProvider)
        .call(SubmitAnswersParams(examId: widget.examId, answers: _answers, textAnswers: textAnswers));
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = result.fold((f) => null, (r) => r);
    });
    // رفع اشکال «شکست بی‌صدا»: قبلاً اگر ارسال شکست می‌خورد (مثلاً همین
    // امتحان قبلاً یک‌بار داده شده بود — کد ۴۰۹ سرور)، شاگرد فقط روی همان
    // فرم می‌ماند بدون هیچ توضیحی. حالا پیام خطا نشان داده می‌شود.
    if (_result == null) {
      result.fold(
        (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
        (_) {},
      );
      return;
    }
    // رفع اشکال «نمایش کهنه»: قبلاً این دو Provider بعد از تحویل امتحان
    // باطل نمی‌شدند — شاگرد با برگشتن به فهرست، همان امتحان را باز هم
    // «قابل‌شروع» می‌دید و نتیجهٔ تازه در «نتایج امتحانات» ظاهر نمی‌شد، مگر
    // با ری‌فرش دستی یا ری‌استارت برنامه.
    ref.invalidate(availableExamsProvider);
    ref.invalidate(myExamResultsProvider(null));

    if (_result!.passed) {
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
      // صنف فعال عوض شده — کش نقشهٔ صنوف برای **همهٔ** صنوف قبلاً واکشی‌شده
      // باطل می‌شود (نه فقط یک صنف خاص) تا وضعیت ارتقا/تکمیل همه‌جا هماهنگ باشد.
      ref.invalidate(gradeMapProvider);
      final studentId = ref.read(authSessionProvider)?.id;
      if (studentId != null) ref.invalidate(dashboardSummaryProvider(studentId));
      NotificationCenter.instance.push(
        title: context.tr('exams.promotedNotifTitle'),
        body: context.tr('exams.promotedNotifBody', {'grade': '${r.newGrade}'}),
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
        error: (e, st) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(examQuestionsProvider(widget.examId)),
            ),
        data: (questions) {
          if (_result != null) {
            return _ResultView(result: _result!);
          }
          return Column(
            children: [
              LinearProgressIndicator(
                value: questions.isEmpty ? 0 : _answeredCount(questions) / questions.length,
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
                    final answered = _isAnswered(q);
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
                          // سؤال تشریحی — جواب متنی (نمره‌دهی AI سمت سرور).
                          if (q.isEssay)
                            TextField(
                              controller: _essayCtrl(q.id),
                              maxLines: 4,
                              minLines: 3,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: context.tr('exams.essayAnswerHint'),
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
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
                    onPressed: questions.isEmpty || _answeredCount(questions) < questions.length
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
    // منبع واحد حقیقت همان `passed`ی است که سرور با آستانهٔ [kExamPassPercent]
    // فرستاده — هماهنگ با فهرست نتایج و داشبورد والدین (رفع اشکال ناهماهنگی).
    final passed = result.passed;
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
              context.tr('exams.correctAnswersCount',
                  {'correct': '${result.correctCount}', 'total': '${result.totalCount}'}),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
            const SizedBox(height: 28),
            if (result.attemptId != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(AppRoutes.examResultReview(result.attemptId!)),
                  icon: const Icon(Icons.fact_check_rounded, size: 18),
                  label: Text(context.tr('exams.reviewAnswersButton')),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
