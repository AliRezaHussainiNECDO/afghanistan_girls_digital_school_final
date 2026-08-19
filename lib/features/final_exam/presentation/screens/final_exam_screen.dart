import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../competition/presentation/providers/competition_providers.dart';
import '../../../grade_map/presentation/providers/grade_map_providers.dart';
import '../../../student_dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/final_exam_entities.dart';
import '../../domain/usecases/final_exam_usecases.dart';
import '../providers/final_exam_providers.dart';

/// امتحان فاینل چندمضمونهٔ صنف — طبق درخواست صاحب پروژه: یک امتحان واحد
/// برای کل صنف (حداقل ۳ سؤال از هر مضمون، حدود ۳۰ سؤال در مجموع). اگر
/// شاگرد قبول نشود، دقیقاً ۱۵ روز بعد دوباره مجاز به تلاش است.
class FinalExamScreen extends ConsumerStatefulWidget {
  const FinalExamScreen({super.key});

  @override
  ConsumerState<FinalExamScreen> createState() => _FinalExamScreenState();
}

class _FinalExamScreenState extends ConsumerState<FinalExamScreen> {
  bool _taking = false;

  @override
  Widget build(BuildContext context) {
    if (_taking) {
      final availAsync = ref.watch(finalExamAvailabilityProvider);
      final exam = availAsync.valueOrNull?.exam;
      if (exam == null) {
        _taking = false;
      } else {
        return _FinalExamTakingScreen(
          examId: exam.id,
          onDone: () {
            setState(() => _taking = false);
            ref.invalidate(finalExamAvailabilityProvider);
            ref.invalidate(myFinalExamResultsProvider(null));
          },
        );
      }
    }

    final availAsync = ref.watch(finalExamAvailabilityProvider);
    final resultsAsync = ref.watch(myFinalExamResultsProvider(null));

    return Scaffold(
      backgroundColor: AppColors.sand50,
      appBar: AppBar(
        title: Text(context.tr('finalExam.title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink900,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(finalExamAvailabilityProvider);
          ref.invalidate(myFinalExamResultsProvider(null));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            availAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: LoadingView()),
              error: (e, st) => ErrorView(error: e, onRetry: () => ref.invalidate(finalExamAvailabilityProvider)),
              data: (avail) => _AvailabilityCard(avail: avail, onStart: () => setState(() => _taking = true)),
            ),
            const SizedBox(height: 20),
            Text(context.tr('finalExam.historyTitle'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 8),
            resultsAsync.when(
              loading: () => const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: LinearProgressIndicator()),
              error: (e, st) => Text('$e', style: const TextStyle(color: AppColors.danger)),
              data: (results) {
                if (results.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(context.tr('finalExam.noAttemptsYet'), style: const TextStyle(color: AppColors.ink500)),
                  );
                }
                return Column(children: results.map((r) => _ResultTile(r: r)).toList());
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  final FinalExamAvailability avail;
  final VoidCallback onStart;
  const _AvailabilityCard({required this.avail, required this.onStart});

  @override
  Widget build(BuildContext context) {
    if (avail.exam == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.lg)),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded, color: AppColors.ink500),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('finalExam.notReady'), style: const TextStyle(color: AppColors.ink700))),
          ],
        ),
      );
    }

    String subtitle;
    Color color;
    IconData icon;
    if (avail.alreadyPassed) {
      subtitle = context.tr('finalExam.alreadyPassed');
      color = AppColors.green600;
      icon = Icons.emoji_events_rounded;
    } else if (avail.inCooldown) {
      final d = avail.retakeAvailableAt;
      subtitle = d != null
          ? context.tr('finalExam.cooldownWithDate',
              {'date': '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}'})
          : context.tr('finalExam.cooldownSoon');
      color = AppColors.orange600;
      icon = Icons.schedule_rounded;
    } else {
      subtitle = context.tr('finalExam.readyToStart', {'count': '${avail.exam!.questionCount}'});
      color = AppColors.orange600;
      icon = Icons.workspace_premium_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.85)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(avail.exam!.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 13)),
          if (avail.eligible) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AppPrimaryButton(label: context.tr('finalExam.startButton'), onPressed: onStart, icon: Icons.play_arrow_rounded, gradient: AppColors.goldCelebrationGradient),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.97, end: 1);
  }
}

class _ResultTile extends StatelessWidget {
  final FinalExamResultSummary r;
  const _ResultTile({required this.r});

  @override
  Widget build(BuildContext context) {
    final color = r.passed ? AppColors.green600 : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.ink300.withValues(alpha: 0.3))),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Text('${r.scorePercent.round()}%', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11)),
        ),
        title: Text(r.examTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
        subtitle: Text(
          '${r.submittedAt.year}/${r.submittedAt.month.toString().padLeft(2, '0')}/${r.submittedAt.day.toString().padLeft(2, '0')}'
          '${r.attemptNumber > 1 ? " · ${context.tr('finalExam.attemptNumber', {'number': '${r.attemptNumber}'})}" : ""}',
          style: const TextStyle(fontSize: 11.5, color: AppColors.ink500),
        ),
        trailing: const Icon(Icons.chevron_left_rounded, color: AppColors.ink300),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _AttemptReviewSheet(attemptId: r.attemptId),
        ),
      ),
    );
  }
}

class _AttemptReviewSheet extends ConsumerWidget {
  final String attemptId;
  const _AttemptReviewSheet({required this.attemptId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(finalExamAttemptReviewProvider(attemptId));
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg))),
        child: reviewAsync.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(error: e),
          data: (review) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.ink300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text(review.examTitle, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(
                  context.tr('finalExam.reviewSummary', {
                    'correct': '${review.correctCount}',
                    'total': '${review.totalCount}',
                    'percent': '${review.scorePercent.round()}'
                  }),
                  style: const TextStyle(color: AppColors.ink500, fontSize: 13)),
              const SizedBox(height: 16),
              ...review.questions.asMap().entries.map((e) => _ReviewQuestionCard(index: e.key + 1, q: e.value)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final int index;
  final FinalExamReviewQuestion q;
  const _ReviewQuestionCard({required this.index, required this.q});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.sand50, borderRadius: BorderRadius.circular(AppRadii.md)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                label: Text(q.subjectNameFa, style: const TextStyle(fontSize: 10.5, color: Colors.white)),
                backgroundColor: AppColors.orange500,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              const Spacer(),
              if (!q.isEssay)
                Icon(q.isCorrect == true ? Icons.check_circle_rounded : Icons.cancel_rounded, color: q.isCorrect == true ? AppColors.green600 : AppColors.danger, size: 18),
            ],
          ),
          const SizedBox(height: 6),
          Text('$index. ${q.text}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          const SizedBox(height: 6),
          if (q.isEssay)
            Text(
                context.tr('chapterQuiz.yourAnswer',
                    {'answer': q.studentAnswerText.isEmpty ? context.tr('chapterQuiz.noAnswer') : q.studentAnswerText}),
                style: const TextStyle(fontSize: 12))
          else ...[
            Text(
                context.tr('chapterQuiz.yourAnswer', {
                  'answer': q.studentAnswerIndex >= 0 && q.studentAnswerIndex < q.options.length
                      ? q.options[q.studentAnswerIndex]
                      : context.tr('chapterQuiz.noAnswer')
                }),
                style: const TextStyle(fontSize: 12)),
            if (q.correctIndex >= 0 && q.correctIndex < q.options.length)
              Text(context.tr('chapterQuiz.correctAnswer', {'answer': q.options[q.correctIndex]}),
                  style: const TextStyle(fontSize: 12, color: AppColors.ink500)),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════ فورم پاسخ‌دهی ═══════════════════════════════

class _FinalExamTakingScreen extends ConsumerStatefulWidget {
  final String examId;
  final VoidCallback onDone;
  const _FinalExamTakingScreen({required this.examId, required this.onDone});

  @override
  ConsumerState<_FinalExamTakingScreen> createState() => _FinalExamTakingScreenState();
}

class _FinalExamTakingScreenState extends ConsumerState<_FinalExamTakingScreen> {
  final Map<String, int> _answers = {};
  final Map<String, TextEditingController> _essayCtrls = {};
  bool _submitting = false;

  TextEditingController _essayCtrl(String qid) => _essayCtrls.putIfAbsent(qid, () => TextEditingController());

  Future<void> _submit(List<FinalExamQuestion> questions) async {
    setState(() => _submitting = true);
    final textAnswers = <String, String>{
      for (final e in _essayCtrls.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    final result = await ref
        .read(submitFinalExamUseCaseProvider)
        .call(SubmitFinalExamParams(examId: widget.examId, answers: _answers, textAnswers: textAnswers));
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
      (r) async {
        if (r.passed) CelebrationOverlay.of(context)?.burst();
        // رفع اشکال (H8 — کهنه‌ماندنِ داشبورد/نقشهٔ صنوف/رقابت بعد از امتحانِ
        // نهایی): قبولی می‌تواند هم امتیازِ فعالیت بدهد و هم صنف را واقعاً
        // ارتقا دهد (promoteIfEligible در progress.ts) — قبلاً فقط
        // finalExamAvailabilityProvider/myFinalExamResultsProvider (توسطِ
        // صفحهٔ والد) باطل می‌شدند؛ خانه/نقشهٔ صنوف/رقابت کهنه می‌ماندند تا
        // خروج کامل از پشتهٔ ناوبری.
        final studentId = ref.read(authSessionProvider)?.id;
        if (studentId != null) ref.invalidate(dashboardSummaryProvider(studentId));
        ref.invalidate(gradeMapProvider);
        ref.read(competitionRefreshProvider.notifier).state++;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
            title: Text(r.passed ? context.tr('finalExam.passedDialogTitle') : context.tr('finalExam.resultDialogTitle')),
            content: Text(
              r.passed
                  ? context.tr('finalExam.passedBody', {'score': '${r.scorePercent.round()}'}) +
                      (r.promoted ? context.tr('finalExam.promotedNote') : '')
                  : context.tr('finalExam.failedBody', {'score': '${r.scorePercent.round()}'}),
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common.ok')))],
          ),
        );
        widget.onDone();
      },
    );
  }

  @override
  void dispose() {
    for (final c in _essayCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(finalExamQuestionsProvider(widget.examId));
    return Scaffold(
      backgroundColor: AppColors.sand50,
      appBar: AppBar(title: Text(context.tr('finalExam.title')), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: AppColors.ink900),
      body: questionsAsync.when(
        loading: () => const LoadingView(),
        // رفع اشکال (H8 — بدون راهِ بازگشت هنگام خطا): قبلاً هیچ دکمهٔ «تلاش
        // دوباره» نبود؛ شاگرد فقط با دکمهٔ بازگشت می‌توانست از صفحهٔ خطا خارج
        // شود. حالا مثل بقیهٔ صفحات نصاب، امکانِ تلاشِ دوبارهٔ بارگذاری هست.
        error: (e, st) => ErrorView(error: e, onRetry: () => ref.invalidate(finalExamQuestionsProvider(widget.examId))),
        data: (questions) {
          // گروه‌بندی بر اساس مضمون تا شاگرد ساختار امتحان را واضح ببیند.
          final bySubject = <String, List<FinalExamQuestion>>{};
          for (final q in questions) {
            bySubject.putIfAbsent(q.subjectNameFa, () => []).add(q);
          }
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    for (final entry in bySubject.entries) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(width: 4, height: 18, color: AppColors.orange500),
                            const SizedBox(width: 8),
                            Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                          ],
                        ),
                      ),
                      ...entry.value.map((q) => _FinalQuestionCard(
                            question: q,
                            essayController: q.isEssay ? _essayCtrl(q.id) : null,
                            onChoice: (i) => _answers[q.id] = i,
                          )),
                    ],
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: AppPrimaryButton(label: context.tr('finalExam.submitButton'), onPressed: () => _submit(questions), loading: _submitting, icon: Icons.send_rounded),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FinalQuestionCard extends StatefulWidget {
  final FinalExamQuestion question;
  final TextEditingController? essayController;
  final ValueChanged<int> onChoice;
  const _FinalQuestionCard({required this.question, this.essayController, required this.onChoice});

  @override
  State<_FinalQuestionCard> createState() => _FinalQuestionCardState();
}

class _FinalQuestionCardState extends State<_FinalQuestionCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: AppColors.ink300.withValues(alpha: 0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 10),
          if (q.isEssay)
            TextField(
              controller: widget.essayController,
              maxLines: 4,
              decoration: InputDecoration(hintText: context.tr('chapterQuiz.essayHint'), filled: true, fillColor: AppColors.sand50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: BorderSide.none)),
            )
          else
            Column(
              children: q.options.asMap().entries.map((e) {
                final selected = _selected == e.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selected = e.key);
                      widget.onChoice(e.key);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: selected ? AppColors.orange500 : AppColors.sand50, borderRadius: BorderRadius.circular(AppRadii.sm)),
                      child: Text(e.value, style: TextStyle(color: selected ? Colors.white : AppColors.ink900, fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
