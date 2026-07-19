import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../shared_models/app_notification.dart';
import '../../data/academy_store.dart';
import '../../domain/academy_entities.dart';
import '../academy_providers.dart';
import 'academy_shared.dart';

void _refreshQ(WidgetRef ref) {
  ref.invalidate(cmsQuestionsListProvider);
}

/// اعلانِ «امتحان به‌روزرسانی شد» هنگام انتشار یک سؤال.
void _notifyExamUpdated(BuildContext context, BankQuestion q) {
  if (q.status != PublishStatus.published) return;
  NotificationCenter.instance.push(
    title: context.tr('academy.newExamNotifTitle'),
    body: context.tr('academy.newExamNotifBody',
        {'subject': q.subject, 'grade': gradeLabel(context, q.gradeId)}),
    kind: NotificationKind.exam,
  );
}

void _toast(BuildContext c, String m) {
  ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));
}

Widget _dropdown<T>(String label, T value, List<(T, String)> items, ValueChanged<T> onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      items: items.map((e) => DropdownMenuItem<T>(value: e.$1, child: Text(e.$2))).toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    ),
  );
}

// ═══════════════════════ QUESTION FORM ═══════════════════════
class QuestionFormSheet extends ConsumerStatefulWidget {
  final BankQuestion? existing;
  const QuestionFormSheet({super.key, this.existing});
  @override
  ConsumerState<QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends ConsumerState<QuestionFormSheet> {
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  late final _chapter = TextEditingController(text: widget.existing?.chapter ?? '');
  late final _model = TextEditingController(text: widget.existing?.modelAnswer ?? '');
  late final _points = TextEditingController(text: (widget.existing?.points ?? 1).toString());
  late final List<TextEditingController> _opts = List.generate(
    4,
    (i) => TextEditingController(
        text: (widget.existing?.options.length ?? 0) > i ? widget.existing!.options[i] : ''),
  );
  late String _subject = widget.existing?.subject ?? kSubjects.first;
  late int _grade = widget.existing?.gradeId ?? 7;
  late QuestionKind _kind = widget.existing?.kind ?? QuestionKind.mcq;
  late int _correctIndex = widget.existing?.correctIndex ?? 0;
  late bool _correctBool = widget.existing?.correctBool ?? true;
  late bool _publish = widget.existing?.status == PublishStatus.published;

  @override
  void dispose() {
    for (final c in [_text, _chapter, _model, _points, ..._opts]) {
      c.dispose();
    }
    super.dispose();
  }

  /// اعتبارسنجی و ساخت رکورد سؤال؛ در صورت نامعتبربودن null برمی‌گرداند.
  BankQuestion? _build() {
    if (_text.text.trim().isEmpty) {
      _toast(context, context.tr('academy.questionTextRequired'));
      return null;
    }
    final opts = _kind == QuestionKind.mcq
        ? _opts.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList()
        : <String>[];
    if (_kind == QuestionKind.mcq && opts.length < 2) {
      _toast(context, context.tr('academy.minTwoOptionsRequired'));
      return null;
    }
    return BankQuestion(
      id: widget.existing?.id ?? 'new',
      subject: _subject,
      gradeId: _grade,
      chapter: _chapter.text.trim(),
      kind: _kind,
      text: _text.text.trim(),
      options: opts,
      correctIndex: _correctIndex.clamp(0, opts.isEmpty ? 0 : opts.length - 1).toInt(),
      correctBool: _correctBool,
      modelAnswer: _model.text.trim(),
      points: int.tryParse(_points.text.trim()) ?? 1,
      status: _publish ? PublishStatus.published : PublishStatus.draft,
      aiGenerated: widget.existing?.aiGenerated ?? false,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
  }

  Future<void> _save() async {
    final q = _build();
    if (q == null) return;
    AcademyStore().saveQuestion(q);
    _refreshQ(ref);
    _notifyExamUpdated(context, q);
    if (mounted) {
      Navigator.pop(context);
      _toast(context, context.tr('academy.questionSaved'));
    }
  }

  /// ذخیره و آماده‌سازی برای سؤال بعدی — برای ساخت سریع چند سؤال پشت‌سرهم.
  /// مضمون/صنف/نوع/فصل حفظ می‌شود و فقط متن و گزینه‌ها پاک می‌گردند.
  void _saveAndNew() {
    final q = _build();
    if (q == null) return;
    AcademyStore().saveQuestion(q);
    _refreshQ(ref);
    _notifyExamUpdated(context, q);
    setState(() {
      _text.clear();
      _model.clear();
      for (final c in _opts) {
        c.clear();
      }
      _correctIndex = 0;
    });
    _toast(context, context.tr('academy.savedEnterNext'));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.existing == null ? context.tr('academy.newQuestionTitle') : context.tr('academy.editQuestionTitle'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              _dropdown<String>(context.tr('academy.subjectLabel'), _subject, kSubjects.map((s) => (s, s)).toList(),
                  (v) => setState(() => _subject = v)),
              _dropdown<int>(context.tr('common.grade'), _grade,
                  kGrades.where((g) => g != 0).map((g) => (g, gradeLabel(context, g))).toList(),
                  (v) => setState(() => _grade = v)),
              academyField(_chapter, context.tr('academy.chapterFieldHint')),
              _dropdown<QuestionKind>(context.tr('academy.questionKindLabel'), _kind, [
                (QuestionKind.mcq, context.tr('academy.kindMcq')),
                (QuestionKind.trueFalse, context.tr('academy.kindTrueFalse')),
                (QuestionKind.essay, context.tr('academy.kindEssay')),
              ], (v) => setState(() => _kind = v)),
              academyField(_text, context.tr('academy.questionTextLabel'), maxLines: 2),
              ..._buildTypeFields(context),
              academyField(_points, context.tr('academy.pointsFieldLabel'), keyboard: TextInputType.number),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _publish,
                onChanged: (v) => setState(() => _publish = v),
                title: Text(context.tr('academy.publishForExamTitle'), style: const TextStyle(fontSize: 14)),
                subtitle: Text(context.tr('academy.publishForExamSubtitle'), style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 8),
              if (widget.existing == null) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _saveAndNew,
                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                    label: Text(context.tr('academy.saveAndAddNext')),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common.cancel')))),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                        onPressed: _save, icon: const Icon(Icons.check_rounded, size: 18), label: Text(context.tr('common.save'))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTypeFields(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (_kind) {
      case QuestionKind.mcq:
        return [
          Text(context.tr('academy.optionsPickCorrectHint'),
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          RadioGroup<int>(
            groupValue: _correctIndex,
            onChanged: (v) => setState(() => _correctIndex = v ?? 0),
            child: Column(
              children: List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Radio<int>(value: i),
                      Expanded(
                        child: TextField(
                          controller: _opts[i],
                          decoration: InputDecoration(
                            labelText: context.tr('academy.optionNumberLabel', {'number': '${i + 1}'}),
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ];
      case QuestionKind.trueFalse:
        return [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(context.tr('academy.correctLabel')), icon: const Icon(Icons.check_rounded)),
                ButtonSegment(value: false, label: Text(context.tr('academy.incorrectLabel')), icon: const Icon(Icons.close_rounded)),
              ],
              selected: {_correctBool},
              onSelectionChanged: (s) => setState(() => _correctBool = s.first),
            ),
          ),
        ];
      case QuestionKind.essay:
        return [academyField(_model, context.tr('academy.modelAnswerFieldHint'), maxLines: 3)];
    }
  }
}

// ═══════════════════════ QUESTION DETAIL ═══════════════════════
class QuestionDetailSheet extends ConsumerWidget {
  final BankQuestion q;
  const QuestionDetailSheet({super.key, required this.q});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final published = q.status == PublishStatus.published;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(spacing: 6, runSpacing: 6, children: [
                KindChip(kind: q.kind),
                PublishChip(status: q.status),
                if (q.aiGenerated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(context.tr('academy.aiGeneratedBadge'),
                        style: const TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w700)),
                  ),
              ]),
              const SizedBox(height: 12),
              Text(q.text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, height: 1.5)),
              const SizedBox(height: 14),
              InfoRow(context.tr('academy.subjectGradeLabel'), '${q.subject} · ${gradeLabel(context, q.gradeId)}'),
              InfoRow(context.tr('academy.chapterLabel'), q.chapter),
              InfoRow(context.tr('academy.pointsFieldLabel'), '${q.points}'),
              if (q.kind == QuestionKind.mcq) ...[
                Text(context.tr('academy.optionsLabel'), style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                ...List.generate(q.options.length, (i) {
                  final correct = i == q.correctIndex;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: correct ? AppColors.green600.withValues(alpha: 0.12) : scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      border: Border.all(color: correct ? AppColors.green600.withValues(alpha: 0.5) : scheme.outlineVariant),
                    ),
                    child: Row(children: [
                      Icon(correct ? Icons.check_circle_rounded : Icons.circle_outlined,
                          size: 18, color: correct ? AppColors.green600 : scheme.onSurfaceVariant),
                      const SizedBox(width: 10),
                      Expanded(child: Text(q.options[i])),
                    ]),
                  );
                }),
              ],
              if (q.kind == QuestionKind.trueFalse)
                InfoRow(context.tr('academy.correctAnswerLabel'),
                    q.correctBool ? context.tr('academy.correctLabel') : context.tr('academy.incorrectLabel')),
              if (q.kind == QuestionKind.essay) InfoRow(context.tr('academy.modelAnswerLabel'), q.modelAnswer),
              const Divider(height: 24),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: (published ? AppColors.ink500 : AppColors.green600).withValues(alpha: 0.14),
                    foregroundColor: published ? AppColors.ink500 : AppColors.green600,
                  ),
                  onPressed: () {
                    AcademyStore().setQuestionStatus(q.id, published ? PublishStatus.draft : PublishStatus.published);
                    _refreshQ(ref);
                    Navigator.pop(context);
                    _toast(context, published ? context.tr('academy.unpublishedNotice') : context.tr('academy.publishedNotice'));
                  },
                  icon: Icon(published ? Icons.unpublished_rounded : Icons.publish_rounded, size: 18),
                  label: Text(published ? context.tr('academy.unpublishButton') : context.tr('academy.publishButton')),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    showAcademySheet(context, QuestionFormSheet(existing: q));
                  },
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: Text(context.tr('academy.editButton')),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                  ),
                  onPressed: () {
                    AcademyStore().deleteQuestion(q.id);
                    _refreshQ(ref);
                    Navigator.pop(context);
                    _toast(context, context.tr('academy.deletedNotice'));
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(context.tr('academy.deleteButton')),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════ AI GENERATE ═══════════════════════
class AiGenerateSheet extends ConsumerStatefulWidget {
  const AiGenerateSheet({super.key});
  @override
  ConsumerState<AiGenerateSheet> createState() => _AiGenerateSheetState();
}

class _AiGenerateSheetState extends ConsumerState<AiGenerateSheet> {
  late final _chapters = TextEditingController();
  late final _count = TextEditingController(text: '5');
  String _subject = kSubjects.first;
  int _grade = 7;
  final Set<QuestionKind> _kinds = {QuestionKind.mcq};
  bool _busy = false;

  @override
  void dispose() {
    _chapters.dispose();
    _count.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_kinds.isEmpty) {
      _toast(context, context.tr('academy.selectAtLeastOneKind'));
      return;
    }
    setState(() => _busy = true);
    try {
      final chapters = _chapters.text
          .split(RegExp(r'[،,\n]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final count = (int.tryParse(_count.text.trim()) ?? 5).clamp(1, 30);
      final service = ref.read(aiAssessmentServiceProvider);
      final generated = await service.generateQuestions(
        subject: _subject,
        gradeId: _grade,
        chapters: chapters,
        kinds: _kinds,
        count: count,
      );
      AcademyStore().addQuestions(generated);
      _refreshQ(ref);
      // بعد از `await service.generateQuestions(...)` بالا.
      if (!mounted) return;
      NotificationCenter.instance.push(
        title: context.tr('academy.aiQuestionsGeneratedNotifTitle'),
        body: context.tr('academy.aiQuestionsGeneratedNotifBody', {
          'count': '${generated.length}',
          'subject': _subject,
          'grade': gradeLabel(context, _grade),
        }),
        kind: NotificationKind.exam,
        priority: NotificationPriority.low,
      );
      if (mounted) {
        Navigator.pop(context);
        _toast(context, context.tr('academy.aiQuestionsGeneratedToast', {'count': '${generated.length}'}));
      }
    } catch (_) {
      if (mounted) _toast(context, context.tr('academy.aiGenerateFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(context.tr('academy.aiGenerateTitle'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
              ]),
              const SizedBox(height: 6),
              Text(context.tr('academy.aiGenerateExplain'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              _dropdown<String>(context.tr('academy.subjectLabel'), _subject, kSubjects.map((s) => (s, s)).toList(),
                  (v) => setState(() => _subject = v)),
              _dropdown<int>(context.tr('common.grade'), _grade,
                  kGrades.where((g) => g != 0).map((g) => (g, gradeLabel(context, g))).toList(),
                  (v) => setState(() => _grade = v)),
              academyField(_chapters, context.tr('academy.chaptersFieldHint'), maxLines: 2),
              academyField(_count, context.tr('academy.questionCountFieldLabel'), keyboard: TextInputType.number),
              const SizedBox(height: 4),
              Text(context.tr('academy.questionKindsLabel'), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                _kindChoice(context.tr('academy.kindMcq'), QuestionKind.mcq),
                _kindChoice(context.tr('academy.kindTrueFalse'), QuestionKind.trueFalse),
                _kindChoice(context.tr('academy.kindEssay'), QuestionKind.essay),
              ]),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _busy ? null : _generate,
                icon: _busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_rounded),
                label: Text(_busy ? context.tr('academy.generatingInProgress') : context.tr('academy.generateQuestionsButton')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kindChoice(String label, QuestionKind k) {
    final selected = _kinds.contains(k);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (s) => setState(() {
        if (s) {
          _kinds.add(k);
        } else {
          _kinds.remove(k);
        }
      }),
    );
  }
}
