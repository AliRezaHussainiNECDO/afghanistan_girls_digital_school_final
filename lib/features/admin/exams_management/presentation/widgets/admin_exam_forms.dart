import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared_models/subject.dart';
import '../../domain/entities/admin_exam_entities.dart';
import '../providers/admin_exams_providers.dart';

/// ۶ صنفِ ثابت مکتب — هماهنگ با جدول واقعی `grades` سرور (۷ تا ۱۲).
const List<int> kExamGrades = [7, 8, 9, 10, 11, 12];

String examTypeLabel(BuildContext context, ExamType t) {
  switch (t) {
    case ExamType.dailyQuiz:
      return context.tr('examAdmin.typeDailyQuiz');
    case ExamType.homework:
      return context.tr('examAdmin.typeHomework');
    case ExamType.monthly:
      return context.tr('examAdmin.typeMonthly');
    case ExamType.finalExam:
      return context.tr('examAdmin.typeFinalExam');
  }
}

String examStatusLabel(BuildContext context, ExamAdminStatus s) {
  switch (s) {
    case ExamAdminStatus.draft:
      return context.tr('examAdmin.statusDraft');
    case ExamAdminStatus.published:
      return context.tr('examAdmin.statusPublished');
    case ExamAdminStatus.closed:
      return context.tr('examAdmin.statusClosed');
  }
}

Color examStatusColor(ExamAdminStatus s) {
  switch (s) {
    case ExamAdminStatus.draft:
      return AppColors.ink500;
    case ExamAdminStatus.published:
      return AppColors.green600;
    case ExamAdminStatus.closed:
      return AppColors.danger;
  }
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );
}

Future<void> showExamSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: child,
    ),
  );
}

class _SheetScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;
  const _SheetScaffold({required this.title, required this.children, required this.onSave});

  @override
  Widget build(BuildContext context) {
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
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              ...children,
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.tr('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(context.tr('common.save')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _field(TextEditingController c, String label, {int maxLines = 1, TextInputType? keyboard}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(label: Text(label), border: const OutlineInputBorder(), isDense: true),
    ),
  );
}

// ═══════════════════════ EXAM FORM ═══════════════════════
class ExamFormSheet extends ConsumerStatefulWidget {
  final AdminExamRow? existing;
  final int? initialGrade;
  const ExamFormSheet({super.key, this.existing, this.initialGrade});
  @override
  ConsumerState<ExamFormSheet> createState() => _ExamFormSheetState();
}

class _ExamFormSheetState extends ConsumerState<ExamFormSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _duration =
      TextEditingController(text: (widget.existing?.durationMinutes ?? 15).toString());
  late int _grade = widget.existing?.gradeNumber ?? widget.initialGrade ?? kExamGrades.first;
  late String _subjectId = widget.existing?.subjectId ?? mockSubjects.first.id;
  late ExamType _type = widget.existing?.type ?? ExamType.dailyQuiz;
  late ExamAdminStatus _status = widget.existing?.status ?? ExamAdminStatus.draft;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _toast(context, context.tr('examAdmin.titleRequired'));
      return;
    }
    setState(() => _saving = true);
    final row = AdminExamRow(
      id: widget.existing?.id ?? 'new',
      subjectId: _subjectId,
      gradeNumber: _grade,
      type: _type,
      title: _title.text.trim(),
      durationMinutes: int.tryParse(_duration.text.trim()) ?? 15,
      status: _status,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );
    try {
      await ref.read(saveExamUseCaseProvider).call(row);
      ref.invalidate(adminExamsProvider);
      if (mounted) {
        Navigator.pop(context);
        _toast(context, context.tr('examAdmin.saved'));
      }
    } catch (e) {
      if (mounted) _toast(context, context.tr('examAdmin.errorWithReason', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: widget.existing == null ? context.tr('examAdmin.newExamTitle') : context.tr('examAdmin.editExamTitle'),
      onSave: _saving ? () async {} : _save,
      children: [
        _field(_title, context.tr('examAdmin.examTitleField')),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<int>(
            initialValue: _grade,
            decoration: InputDecoration(label: Text(context.tr('examAdmin.gradeField')), border: const OutlineInputBorder(), isDense: true),
            items: kExamGrades.map((g) => DropdownMenuItem(value: g, child: Text(context.tr('bulkImport.gradeOption', {'grade': '$g'})))).toList(),
            onChanged: (v) => setState(() => _grade = v ?? kExamGrades.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _subjectId,
            decoration: InputDecoration(label: Text(context.tr('examAdmin.subjectField')), border: const OutlineInputBorder(), isDense: true),
            items: mockSubjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nameFa))).toList(),
            onChanged: (v) => setState(() => _subjectId = v ?? mockSubjects.first.id),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<ExamType>(
            initialValue: _type,
            decoration: InputDecoration(label: Text(context.tr('examAdmin.examTypeField')), border: const OutlineInputBorder(), isDense: true),
            items: ExamType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(examTypeLabel(context, t))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? ExamType.dailyQuiz),
          ),
        ),
        _field(_duration, context.tr('examAdmin.durationMinutesField'), keyboard: TextInputType.number),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: DropdownButtonFormField<ExamAdminStatus>(
            initialValue: _status,
            decoration: InputDecoration(label: Text(context.tr('examAdmin.statusField')), border: const OutlineInputBorder(), isDense: true),
            items: ExamAdminStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(examStatusLabel(context, s))))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? ExamAdminStatus.draft),
          ),
        ),
        if (_type == ExamType.finalExam)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              context.tr('examAdmin.finalExamNotice'),
              style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

// ═══════════════════════ QUESTION FORM ═══════════════════════
class ExamQuestionFormSheet extends ConsumerStatefulWidget {
  final String examId;
  final AdminQuestionRow? existing;
  const ExamQuestionFormSheet({super.key, required this.examId, this.existing});
  @override
  ConsumerState<ExamQuestionFormSheet> createState() => _ExamQuestionFormSheetState();
}

String questionTypeLabel(BuildContext context, QuestionType t) {
  switch (t) {
    case QuestionType.mcq:
      return context.tr('examAdmin.qTypeMcq');
    case QuestionType.trueFalse:
      return context.tr('examAdmin.qTypeTrueFalse');
    case QuestionType.essay:
      return context.tr('examAdmin.qTypeEssay');
  }
}

class _ExamQuestionFormSheetState extends ConsumerState<ExamQuestionFormSheet> {
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  late final _answerText = TextEditingController(text: widget.existing?.answerText ?? '');
  late final List<TextEditingController> _opts = List.generate(
    4,
    (i) => TextEditingController(
      text: (widget.existing != null && i < widget.existing!.options.length) ? widget.existing!.options[i] : '',
    ),
  );
  late QuestionType _qType = widget.existing?.qType ?? QuestionType.mcq;
  late int _correctIndex = widget.existing?.correctIndex ?? 0;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _answerText.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      _toast(context, context.tr('examAdmin.questionTextRequired'));
      return;
    }
    // اعتبارسنجی/ساخت بر اساس نوع سؤال — هماهنگ با backend (migration 0030).
    List<String> opts;
    int correctIndex;
    switch (_qType) {
      case QuestionType.essay:
        opts = const [];
        correctIndex = -1;
        break;
      case QuestionType.trueFalse:
        opts = [context.tr('examAdmin.trueOption'), context.tr('examAdmin.falseOption')];
        correctIndex = _correctIndex == 1 ? 1 : 0;
        break;
      case QuestionType.mcq:
        opts = _opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
        if (opts.length < 2) {
          _toast(context, context.tr('examAdmin.questionAndOptionsRequired'));
          return;
        }
        correctIndex = _correctIndex >= opts.length ? 0 : _correctIndex;
        break;
    }
    setState(() => _saving = true);
    final row = AdminQuestionRow(
      id: widget.existing?.id ?? 'new',
      examId: widget.examId,
      text: _text.text.trim(),
      qType: _qType,
      options: opts,
      correctIndex: correctIndex,
      orderIndex: widget.existing?.orderIndex ?? 0,
      answerText: _qType == QuestionType.essay ? _answerText.text.trim() : '',
    );
    try {
      await ref.read(saveQuestionUseCaseProvider).call(row);
      ref.invalidate(adminExamQuestionsProvider(widget.examId));
      ref.invalidate(adminExamsProvider);
      if (mounted) {
        Navigator.pop(context);
        _toast(context, context.tr('examAdmin.saved'));
      }
    } catch (e) {
      if (mounted) _toast(context, context.tr('examAdmin.errorWithReason', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SheetScaffold(
      title: widget.existing == null ? context.tr('examAdmin.newQuestionTitle') : context.tr('examAdmin.editQuestionTitle'),
      onSave: _saving ? () async {} : _save,
      children: [
        // نوع سؤال — چهارگزینه‌ای / صحیح‌وغلط / تشریحی (migration 0030).
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SegmentedButton<QuestionType>(
            segments: QuestionType.values
                .map((t) => ButtonSegment(value: t, label: Text(questionTypeLabel(context, t), style: const TextStyle(fontSize: 12))))
                .toList(),
            selected: {_qType},
            onSelectionChanged: (s) => setState(() {
              _qType = s.first;
              if (_qType == QuestionType.trueFalse && _correctIndex > 1) _correctIndex = 0;
            }),
          ),
        ),
        _field(_text, context.tr('examAdmin.questionTextField'), maxLines: 2),
        if (_qType == QuestionType.mcq) ...[
          const SizedBox(height: 4),
          Text(context.tr('examAdmin.optionsHint'),
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          RadioGroup<int>(
            groupValue: _correctIndex,
            onChanged: (v) => setState(() => _correctIndex = v ?? 0),
            child: Column(
              children: List.generate(4, (i) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Radio<int>(value: i),
                      Expanded(
                        child: TextField(
                          controller: _opts[i],
                          decoration: InputDecoration(
                            label: Text(context.tr('examAdmin.optionField', {'number': '${i + 1}'})),
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
        ],
        if (_qType == QuestionType.trueFalse) ...[
          const SizedBox(height: 4),
          Text(context.tr('examAdmin.trueFalseHint'),
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          RadioGroup<int>(
            groupValue: _correctIndex,
            onChanged: (v) => setState(() => _correctIndex = v ?? 0),
            child: Column(
              children: List.generate(2, (i) {
                final label = i == 0 ? context.tr('examAdmin.trueOption') : context.tr('examAdmin.falseOption');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Radio<int>(value: i),
                      Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
        if (_qType == QuestionType.essay) ...[
          const SizedBox(height: 4),
          Text(context.tr('examAdmin.essayHint'),
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          _field(_answerText, context.tr('examAdmin.modelAnswerField'), maxLines: 3),
        ],
      ],
    );
  }
}

// ═══════════════════════ AI QUESTION GENERATION ═══════════════════════
/// «تولید سؤال با هوش مصنوعی» — مدیر تعداد دلخواه از هر نوع سؤال را انتخاب
/// می‌کند؛ صنف و مضمون از خودِ امتحان گرفته می‌شود و سرور سؤالات دری متناسب
/// با نصاب همان صنف تولید و مستقیم ذخیره می‌کند.
class ExamAiGenerateSheet extends ConsumerStatefulWidget {
  final String examId;
  const ExamAiGenerateSheet({super.key, required this.examId});
  @override
  ConsumerState<ExamAiGenerateSheet> createState() => _ExamAiGenerateSheetState();
}

class _ExamAiGenerateSheetState extends ConsumerState<ExamAiGenerateSheet> {
  final _topic = TextEditingController();
  int _mcq = 5;
  int _trueFalse = 3;
  int _essay = 2;
  bool _generating = false;

  @override
  void dispose() {
    _topic.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_mcq + _trueFalse + _essay == 0) {
      _toast(context, context.tr('examAdmin.aiAtLeastOne'));
      return;
    }
    setState(() => _generating = true);
    final result = await ref.read(generateQuestionsUseCaseProvider).call(GenerateQuestionsParams(
          examId: widget.examId,
          mcqCount: _mcq,
          trueFalseCount: _trueFalse,
          essayCount: _essay,
          topic: _topic.text.trim(),
        ));
    if (!mounted) return;
    setState(() => _generating = false);
    result.fold(
      (f) => _toast(context, context.tr('examAdmin.errorWithReason', {'error': f.message})),
      (questions) {
        ref.invalidate(adminExamQuestionsProvider(widget.examId));
        ref.invalidate(adminExamsProvider);
        Navigator.pop(context);
        _toast(context, context.tr('examAdmin.aiGeneratedCount', {'count': '${questions.length}'}));
      },
    );
  }

  Widget _counter(String label, int value, ValueChanged<int> onChanged) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value <= 0 ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
          ),
          SizedBox(
            width: 34,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: scheme.primary)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: value >= 30 ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline_rounded, size: 22),
          ),
        ],
      ),
    );
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
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(context.tr('examAdmin.aiGenerateTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(context.tr('examAdmin.aiGenerateSubtitle'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 16),
              _counter(context.tr('examAdmin.qTypeMcq'), _mcq, (v) => setState(() => _mcq = v)),
              _counter(context.tr('examAdmin.qTypeTrueFalse'), _trueFalse, (v) => setState(() => _trueFalse = v)),
              _counter(context.tr('examAdmin.qTypeEssay'), _essay, (v) => setState(() => _essay = v)),
              const SizedBox(height: 4),
              _field(_topic, context.tr('examAdmin.aiTopicField')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _generating ? null : () => Navigator.pop(context),
                      child: Text(context.tr('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _generating ? null : _generate,
                      icon: _generating
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(_generating
                          ? context.tr('examAdmin.aiGenerating')
                          : context.tr('examAdmin.aiGenerateButton')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
