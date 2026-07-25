import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart' show chaptersProvider;
import '../../../exams/domain/entities/exam_entities.dart' show QuestionType;
import '../../domain/entities/chapter_quiz_entities.dart';
import '../../domain/usecases/chapter_quiz_usecases.dart';
import '../providers/chapter_quiz_providers.dart';

/// «آزمون فصل» — طبق درخواست صاحب پروژه: بعد از دیدن تمام درس‌های یک فصل،
/// این صفحه با لحن تشویقی (نه سخت‌گیرانه) باز می‌شود؛ صرفِ ارسال آن فصل
/// بعدی را باز می‌کند. اگر شاگرد قبلاً داده باشد، همین صفحه فورم مرور
/// (سؤال/پاسخ/پاسخ‌درست) را نشان می‌دهد.
class ChapterQuizScreen extends ConsumerStatefulWidget {
  final String chapterId;
  final String subjectId;
  const ChapterQuizScreen({super.key, required this.chapterId, required this.subjectId});

  @override
  ConsumerState<ChapterQuizScreen> createState() => _ChapterQuizScreenState();
}

class _ChapterQuizScreenState extends ConsumerState<ChapterQuizScreen> {
  final Map<String, int> _answers = {};
  final Map<String, TextEditingController> _essayCtrls = {};
  bool _submitting = false;

  TextEditingController _essayCtrl(String qid) => _essayCtrls.putIfAbsent(qid, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _essayCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(List<ChapterQuizQuestion> questions) async {
    setState(() => _submitting = true);
    final textAnswers = <String, String>{
      for (final e in _essayCtrls.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    final result = await ref
        .read(submitChapterQuizUseCaseProvider)
        .call(SubmitChapterQuizParams(chapterId: widget.chapterId, answers: _answers, textAnswers: textAnswers));
    if (!mounted) return;
    setState(() => _submitting = false);
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
      (r) {
        if (r.passed) CelebrationOverlay.of(context)?.burst();
        // رفع کهنه‌ماندن: بعد از ارسال، هم فورم این آزمون (که حالا باید حالت
        // «مرور» نشان دهد) و هم فهرست فصل‌ها (فصل بعدی باید unlocked شود) تازه شوند.
        ref.invalidate(chapterQuizProvider(widget.chapterId));
        ref.invalidate(chaptersProvider(widget.subjectId));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formAsync = ref.watch(chapterQuizProvider(widget.chapterId));

    return Scaffold(
      backgroundColor: AppColors.sand50,
      appBar: AppBar(
        title: Text(context.tr('chapterQuiz.title')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink900,
      ),
      body: formAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e, onRetry: () => ref.invalidate(chapterQuizProvider(widget.chapterId))),
        data: (form) {
          if (form.isNotReady) return _NotReadyView(onRetry: () => ref.invalidate(chapterQuizProvider(widget.chapterId)));
          if (form.submitted) return _ReviewBody(form: form);
          return _TakingBody(
            form: form,
            answers: _answers,
            essayCtrl: _essayCtrl,
            submitting: _submitting,
            onSubmit: () => _submit(form.questions),
          );
        },
      ),
    );
  }
}

class _NotReadyView extends StatelessWidget {
  final VoidCallback onRetry;
  const _NotReadyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 56, color: AppColors.ink300),
            const SizedBox(height: 16),
            Text(context.tr('chapterQuiz.notReadyTitle'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 6),
            Text(
              context.tr('chapterQuiz.notReadyBody'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink500, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(width: 160, child: AppPrimaryButton(label: context.tr('common.retry'), onPressed: onRetry, icon: Icons.refresh_rounded)),
          ],
        ),
      ),
    );
  }
}

class _TakingBody extends StatelessWidget {
  final ChapterQuizForm form;
  final Map<String, int> answers;
  final TextEditingController Function(String) essayCtrl;
  final bool submitting;
  final VoidCallback onSubmit;

  const _TakingBody({
    required this.form,
    required this.answers,
    required this.essayCtrl,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(gradient: AppColors.heroGradientWarm, borderRadius: BorderRadius.circular(AppRadii.md)),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_objects_rounded, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        context.tr('chapterQuiz.introBanner'),
                        style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ...form.questions.asMap().entries.map(
                    (e) => _QuestionCard(
                      index: e.key + 1,
                      question: e.value,
                      essayController: e.value.isEssay ? essayCtrl(e.value.id) : null,
                      onChoice: (i) => answers[e.value.id] = i,
                    ).animate().fadeIn(delay: (40 * e.key).ms, duration: 250.ms).slideY(begin: 0.08, end: 0),
                  ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: AppPrimaryButton(label: context.tr('chapterQuiz.submitButton'), onPressed: onSubmit, loading: submitting, icon: Icons.send_rounded),
          ),
        ),
      ],
    );
  }
}

class _QuestionCard extends StatefulWidget {
  final int index;
  final ChapterQuizQuestion question;
  final TextEditingController? essayController;
  final ValueChanged<int> onChoice;
  const _QuestionCard({required this.index, required this.question, this.essayController, required this.onChoice});

  @override
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.ink300.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.orange500.withValues(alpha: 0.15),
                child: Text('${widget.index}', style: const TextStyle(fontSize: 12, color: AppColors.orange600, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5))),
            ],
          ),
          const SizedBox(height: 12),
          if (q.isEssay)
            TextField(
              controller: widget.essayController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.tr('chapterQuiz.essayHint'),
                filled: true,
                fillColor: AppColors.sand50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.sm), borderSide: BorderSide.none),
              ),
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
                      decoration: BoxDecoration(
                        color: selected ? AppColors.orange500 : AppColors.sand50,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Text(
                        e.value,
                        style: TextStyle(color: selected ? Colors.white : AppColors.ink900, fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
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

class _ReviewBody extends StatelessWidget {
  final ChapterQuizForm form;
  const _ReviewBody({required this.form});

  @override
  Widget build(BuildContext context) {
    final pct = form.scorePercent ?? 0;
    final passed = form.passed ?? false;
    final color = passed ? AppColors.green600 : AppColors.orange600;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.85)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(AppRadii.lg),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                        value: pct / 100, strokeWidth: 6, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white)),
                  ),
                  Text('${pct.round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(passed ? context.tr('chapterQuiz.passedTitle') : context.tr('chapterQuiz.tryAgainTitle'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5)),
                    const SizedBox(height: 4),
                    Text(
                        context.tr('chapterQuiz.correctOutOf',
                            {'correct': '${form.correctCount ?? 0}', 'total': '${form.totalCount ?? 0}'}),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.96, end: 1),
        const SizedBox(height: 16),
        ...?form.reviewQuestions?.asMap().entries.map((e) => _ReviewQuestionCard(index: e.key + 1, q: e.value)),
      ],
    );
  }
}

class _ReviewQuestionCard extends StatelessWidget {
  final int index;
  final ChapterQuizReviewQuestion q;
  const _ReviewQuestionCard({required this.index, required this.q});

  @override
  Widget build(BuildContext context) {
    final borderColor = q.isEssay ? AppColors.ink300.withValues(alpha: 0.3) : (q.isCorrect == true ? AppColors.green500 : AppColors.danger).withValues(alpha: 0.4);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadii.md), border: Border.all(color: borderColor)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppColors.orange500.withValues(alpha: 0.15),
                child: Text('$index', style: const TextStyle(fontSize: 12, color: AppColors.orange600, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
              if (!q.isEssay)
                Icon(q.isCorrect == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
                    color: q.isCorrect == true ? AppColors.green600 : AppColors.danger, size: 20),
            ],
          ),
          const SizedBox(height: 8),
          if (q.isEssay) ...[
            Text(
                context.tr('chapterQuiz.yourAnswer',
                    {'answer': q.studentAnswerText.isEmpty ? context.tr('chapterQuiz.noAnswer') : q.studentAnswerText}),
                style: const TextStyle(fontSize: 12.5)),
            if (q.essayScore != null) ...[
              const SizedBox(height: 4),
              Text(context.tr('chapterQuiz.feedback', {'feedback': q.essayFeedback}),
                  style: const TextStyle(fontSize: 12, color: AppColors.ink500, fontStyle: FontStyle.italic)),
            ],
          ] else if (q.qType != QuestionType.essay) ...[
            Text(
              context.tr('chapterQuiz.yourAnswer', {
                'answer': q.studentAnswerIndex >= 0 && q.studentAnswerIndex < q.options.length
                    ? q.options[q.studentAnswerIndex]
                    : context.tr('chapterQuiz.noAnswer')
              }),
              style: const TextStyle(fontSize: 12.5),
            ),
            if (q.correctIndex >= 0 && q.correctIndex < q.options.length)
              Text(context.tr('chapterQuiz.correctAnswer', {'answer': q.options[q.correctIndex]}),
                  style: const TextStyle(fontSize: 12.5, color: AppColors.ink500)),
          ],
        ],
      ),
    );
  }
}
