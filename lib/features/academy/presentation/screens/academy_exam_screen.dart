import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../shared_models/app_notification.dart';
import '../../data/academy_store.dart';
import '../../domain/academy_entities.dart';
import '../academy_providers.dart';
import '../widgets/academy_shared.dart';

/// صفحهٔ گرفتن «تمرین» یک مضمون (مضمون+صنف) — پشتیبانی از سه نوع سؤال،
/// ارسال، نمره‌دهی خودکار (سؤالات بسته) و نمره‌دهی تشریحی با هوش مصنوعی،
/// و نمایش پویا و مدرن نتیجه.
///
/// **نکتهٔ مهم دربارهٔ ارتقا:** این یک امتحان تمرینیِ مضمون است، نه امتحان
/// نهاییِ صنف. قبلاً اینجا با `ProgressionStore` (یک انبار محلیِ گوشی که
/// اصلاً به سرور وصل نبود و حتی با شناسه‌های شاگرد نمونهٔ ثابت Seed می‌شد)
/// یک «ارتقای» جعلی شبیه‌سازی می‌شد — یعنی به شاگرد گفته می‌شد ارتقا یافته
/// در حالی که `current_grade` واقعی روی سرور هرگز تغییر نمی‌کرد و با ورود
/// بعدی یا در هر صفحهٔ دیگر (نصاب/داشبورد/نقشهٔ صنف که همه از سرور می‌خوانند)
/// اثری از آن دیده نمی‌شد. ارتقای واقعی اکنون فقط از مسیر «امتحان نهایی
/// صنف» (صفحهٔ `ExamsScreen` → `ExamTakingScreen` → `POST /exams/:id/submit`
/// → `promoteIfEligible` روی سرور) اتفاق می‌افتد.
class AcademyExamScreen extends ConsumerStatefulWidget {
  final String subject;
  final int gradeId;
  const AcademyExamScreen({super.key, required this.subject, required this.gradeId});

  @override
  ConsumerState<AcademyExamScreen> createState() => _AcademyExamScreenState();
}

class _AcademyExamScreenState extends ConsumerState<AcademyExamScreen> {
  final Map<String, int> _mcq = {};
  final Map<String, bool> _tf = {};
  final Map<String, TextEditingController> _essay = {};
  bool _submitting = false;
  Submission? _result;

  @override
  void dispose() {
    for (final c in _essay.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _essayController(String id) => _essay.putIfAbsent(id, () => TextEditingController());

  Future<void> _submit(List<BankQuestion> questions) async {
    setState(() => _submitting = true);
    try {
      final service = ref.read(aiAssessmentServiceProvider);
      final student = ref.read(currentStudentProvider);
      final answers = <SubmissionAnswer>[];
      double earned = 0;
      double total = 0;
      var hasEssay = false;

      for (final q in questions) {
        final max = q.points.toDouble();
        total += max;
        switch (q.kind) {
          case QuestionKind.mcq:
            final chosen = _mcq[q.id];
            final correct = chosen != null && chosen == q.correctIndex;
            final aw = correct ? max : 0.0;
            earned += aw;
            answers.add(SubmissionAnswer(
              questionId: q.id,
              questionText: q.text,
              kind: q.kind,
              options: q.options,
              chosenIndex: chosen,
              correctIndex: q.correctIndex,
              awardedPoints: aw,
              maxPoints: max,
              isCorrect: correct,
            ));
            break;
          case QuestionKind.trueFalse:
            final chosen = _tf[q.id];
            final correct = chosen != null && chosen == q.correctBool;
            final aw = correct ? max : 0.0;
            earned += aw;
            answers.add(SubmissionAnswer(
              questionId: q.id,
              questionText: q.text,
              kind: q.kind,
              chosenBool: chosen,
              correctBool: q.correctBool,
              awardedPoints: aw,
              maxPoints: max,
              isCorrect: correct,
            ));
            break;
          case QuestionKind.essay:
            hasEssay = true;
            final text = _essayController(q.id).text.trim();
            final grade = await service.gradeEssay(
              questionText: q.text,
              modelAnswer: q.modelAnswer,
              studentAnswer: text,
            );
            final aw = grade.fraction * max;
            earned += aw;
            answers.add(SubmissionAnswer(
              questionId: q.id,
              questionText: q.text,
              kind: q.kind,
              essayText: text,
              modelAnswer: q.modelAnswer,
              awardedPoints: double.parse(aw.toStringAsFixed(1)),
              maxPoints: max,
              aiFeedback: grade.feedback,
            ));
            break;
        }
      }

      final scorePercent = total == 0 ? 0.0 : (earned / total) * 100;
      final submission = AcademyStore().saveSubmission(Submission(
        id: 'new',
        studentId: student.id,
        studentName: student.displayName,
        gradeId: widget.gradeId,
        subject: widget.subject,
        submittedAt: DateTime.now(),
        answers: answers,
        scorePercent: double.parse(scorePercent.toStringAsFixed(1)),
        earnedPoints: double.parse(earned.toStringAsFixed(1)),
        totalPoints: total,
        aiAssisted: hasEssay,
      ));
      ref.invalidate(mySubmissionsProvider);
      ref.invalidate(allSubmissionsProvider);
      // بعد از `await service.gradeEssay(...)` بالا — قبل از استفادهٔ بعدی از
      // context باید مطمئن شویم ویجت هنوز در درخت است.
      if (!mounted) return;
      NotificationCenter.instance.push(
        title: submission.passed
            ? context.tr('academy.practiceScoreNotifTitlePassed')
            : context.tr('academy.practiceScoreNotifTitle'),
        body: context.tr('academy.practiceScoreNotifBody', {
          'subject': submission.subject,
          'grade': gradeLabel(context, submission.gradeId),
          'percent': submission.scorePercent.toStringAsFixed(0),
        }),
        kind: NotificationKind.grade,
        priority: submission.passed ? NotificationPriority.medium : NotificationPriority.high,
      );

      if (mounted) {
        setState(() => _result = submission);
        if (submission.passed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            CelebrationOverlay.of(context)?.burst();
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('academy.submitFailed')), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(examQuestionsProvider('${widget.subject}#${widget.gradeId}'));
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
            context.tr('academy.practiceTitle',
                {'subject': widget.subject, 'grade': gradeLabel(context, widget.gradeId)}),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(e.toString())),
        data: (questions) {
          if (_result != null) return _ResultView(result: _result!);
          if (questions.isEmpty) {
            return Center(child: Text(context.tr('academy.noQuestionsYetForPractice')));
          }
          return _buildTaking(context, questions);
        },
      ),
    );
  }

  Widget _buildTaking(BuildContext context, List<BankQuestion> questions) {
    return Column(
      children: [
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) {
              return _QuestionInput(
                index: i,
                q: questions[i],
                mcqValue: _mcq[questions[i].id],
                tfValue: _tf[questions[i].id],
                essayController: questions[i].kind == QuestionKind.essay ? _essayController(questions[i].id) : null,
                onMcq: (v) => setState(() => _mcq[questions[i].id] = v),
                onTf: (v) => setState(() => _tf[questions[i].id] = v),
              ).animate().fadeIn(delay: (40 * i).ms, duration: 260.ms).slideY(begin: 0.06);
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _submitting ? null : () => _submit(questions),
                icon: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_submitting
                    ? context.tr('academy.scoringInProgress')
                    : context.tr('academy.submitAndSeeScore')),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuestionInput extends StatelessWidget {
  final int index;
  final BankQuestion q;
  final int? mcqValue;
  final bool? tfValue;
  final TextEditingController? essayController;
  final ValueChanged<int> onMcq;
  final ValueChanged<bool> onTf;

  const _QuestionInput({
    required this.index,
    required this.q,
    required this.mcqValue,
    required this.tfValue,
    required this.essayController,
    required this.onMcq,
    required this.onTf,
  });

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(radius: 13, backgroundColor: scheme.primaryContainer, child: Text('${index + 1}', style: TextStyle(fontSize: 12, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700))),
              const SizedBox(width: 10),
              KindChip(kind: q.kind),
              const Spacer(),
              Text(context.tr('academy.pointsLabel', {'points': '${q.points}'}),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Text(q.text, style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
          const SizedBox(height: 12),
          ..._inputs(context),
        ],
      ),
    );
  }

  List<Widget> _inputs(BuildContext context) {
    switch (q.kind) {
      case QuestionKind.mcq:
        return [
          RadioGroup<int>(
            groupValue: mcqValue,
            onChanged: (v) => onMcq(v ?? 0),
            child: Column(
              children: List.generate(q.options.length, (i) {
                return RadioListTile<int>(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  value: i,
                  title: Text(q.options[i]),
                );
              }),
            ),
          ),
        ];
      case QuestionKind.trueFalse:
        return [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                  value: true, label: Text(context.tr('academy.correctLabel')), icon: const Icon(Icons.check_rounded)),
              ButtonSegment(
                  value: false, label: Text(context.tr('academy.incorrectLabel')), icon: const Icon(Icons.close_rounded)),
            ],
            selected: tfValue == null ? <bool>{} : {tfValue!},
            emptySelectionAllowed: true,
            onSelectionChanged: (s) {
              if (s.isNotEmpty) onTf(s.first);
            },
          ),
        ];
      case QuestionKind.essay:
        return [
          TextField(
            controller: essayController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: context.tr('academy.essayAnswerHint'),
              border: const OutlineInputBorder(),
            ),
          ),
        ];
    }
  }
}

class _ResultView extends StatelessWidget {
  final Submission result;
  const _ResultView({required this.result});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final passed = result.passed;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // کارت نمرهٔ کل
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: passed ? [AppColors.green500, AppColors.green700] : [AppColors.orange500, AppColors.orange700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: AppShadows.warm,
          ),
          child: Column(
            children: [
              Icon(passed ? Icons.emoji_events_rounded : Icons.school_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              Text('${result.scorePercent.toStringAsFixed(0)}٪',
                  style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w900)),
              Text(
                  context.tr('academy.pointsEarnedOfTotal', {
                    'earned': result.earnedPoints.toStringAsFixed(1),
                    'total': result.totalPoints.toStringAsFixed(0),
                  }),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9))),
              const SizedBox(height: 6),
              Text(
                  passed
                      ? context.tr('academy.practicePassedCongrats')
                      : context.tr('academy.practiceFailedEncourage'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95)),
        const SizedBox(height: 16),
        Text(context.tr('academy.reviewAnswers'),
            style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
        const SizedBox(height: 10),
        ...result.answers.map((a) => _answerCard(context, a)),
        const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.check_rounded),
          label: Text(context.tr('academy.finishButton')),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(context.tr('academy.scoreVisibleToParentNotice'),
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        ),
      ],
    );
  }

  Widget _answerCard(BuildContext context, SubmissionAnswer a) {
    final scheme = Theme.of(context).colorScheme;
    final full = a.awardedPoints >= a.maxPoints;
    final partial = a.awardedPoints > 0 && !full;
    final color = full ? AppColors.green600 : (partial ? AppColors.gold600 : AppColors.danger);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(full ? Icons.check_circle_rounded : (partial ? Icons.timelapse_rounded : Icons.cancel_rounded),
                  color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(a.questionText, style: const TextStyle(fontWeight: FontWeight.w700))),
              Text('${a.awardedPoints.toStringAsFixed(1)}/${a.maxPoints.toStringAsFixed(0)}',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ],
          ),
          if (a.kind == QuestionKind.mcq && a.correctIndex != null && a.options.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
                context.tr('academy.correctAnswerPrefix', {
                  'answer': a.options[a.correctIndex!.clamp(0, a.options.length - 1).toInt()]
                }),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            if (a.chosenIndex != null && a.chosenIndex != a.correctIndex)
              Text(
                  context.tr('academy.yourAnswerPrefix', {
                    'answer': a.options[a.chosenIndex!.clamp(0, a.options.length - 1).toInt()]
                  }),
                  style: const TextStyle(fontSize: 12, color: AppColors.danger)),
          ],
          if (a.kind == QuestionKind.trueFalse && a.correctBool != null) ...[
            const SizedBox(height: 8),
            Text(
                context.tr('academy.correctAnswerPrefix', {
                  'answer': a.correctBool!
                      ? context.tr('academy.correctLabel')
                      : context.tr('academy.incorrectLabel')
                }),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
          if (a.kind == QuestionKind.essay && a.aiFeedback.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.info),
                  const SizedBox(width: 8),
                  Expanded(child: Text(a.aiFeedback, style: const TextStyle(fontSize: 12, height: 1.5))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
