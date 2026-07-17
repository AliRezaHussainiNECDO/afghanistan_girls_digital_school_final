import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared_models/subject.dart';
import '../../../../exams/domain/entities/exam_entities.dart';
import '../../domain/entities/admin_exam_entities.dart';
import '../providers/admin_exams_providers.dart';

/// ۶ صنفِ ثابت مکتب — هماهنگ با جدول واقعی `grades` سرور (۷ تا ۱۲).
const List<int> kExamGrades = [7, 8, 9, 10, 11, 12];

String examTypeLabel(BuildContext context, ExamType t) {
  switch (t) {
    case ExamType.dailyQuiz:
      return 'کوییز روزانه';
    case ExamType.homework:
      return 'کارخانگی';
    case ExamType.monthly:
      return 'امتحان ماهانه';
    case ExamType.finalExam:
      return 'امتحان نهایی';
  }
}

String examStatusLabel(ExamAdminStatus s) {
  switch (s) {
    case ExamAdminStatus.draft:
      return 'پیش‌نویس';
    case ExamAdminStatus.published:
      return 'منتشرشده';
    case ExamAdminStatus.closed:
      return 'بسته‌شده';
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
      _toast(context, 'عنوان امتحان لازم است');
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
        _toast(context, 'ذخیره شد');
      }
    } catch (e) {
      if (mounted) _toast(context, 'خطا: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: widget.existing == null ? 'امتحان جدید' : 'ویرایش امتحان',
      onSave: _saving ? () async {} : _save,
      children: [
        _field(_title, 'عنوان امتحان'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<int>(
            initialValue: _grade,
            decoration: const InputDecoration(label: Text('صنف'), border: OutlineInputBorder(), isDense: true),
            items: kExamGrades.map((g) => DropdownMenuItem(value: g, child: Text('صنف $g'))).toList(),
            onChanged: (v) => setState(() => _grade = v ?? kExamGrades.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _subjectId,
            decoration: const InputDecoration(label: Text('مضمون'), border: OutlineInputBorder(), isDense: true),
            items: mockSubjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nameFa))).toList(),
            onChanged: (v) => setState(() => _subjectId = v ?? mockSubjects.first.id),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<ExamType>(
            initialValue: _type,
            decoration: const InputDecoration(label: Text('نوع امتحان'), border: OutlineInputBorder(), isDense: true),
            items: ExamType.values
                .map((t) => DropdownMenuItem(value: t, child: Text(examTypeLabel(context, t))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? ExamType.dailyQuiz),
          ),
        ),
        _field(_duration, 'مدت (دقیقه)', keyboard: TextInputType.number),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: DropdownButtonFormField<ExamAdminStatus>(
            initialValue: _status,
            decoration: const InputDecoration(label: Text('وضعیت'), border: OutlineInputBorder(), isDense: true),
            items: ExamAdminStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(examStatusLabel(s))))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? ExamAdminStatus.draft),
          ),
        ),
        if (_type == ExamType.finalExam)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'این امتحان «نهایی» است — کامیابی در آن (+ تکمیل همهٔ مضامین) شرط ارتقای شاگرد به صنف بعدی است.',
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

class _ExamQuestionFormSheetState extends ConsumerState<ExamQuestionFormSheet> {
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  late final List<TextEditingController> _opts = List.generate(
    4,
    (i) => TextEditingController(
      text: (widget.existing != null && i < widget.existing!.options.length) ? widget.existing!.options[i] : '',
    ),
  );
  late int _correctIndex = widget.existing?.correctIndex ?? 0;
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    for (final c in _opts) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final opts = _opts.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
    if (_text.text.trim().isEmpty || opts.length < 2) {
      _toast(context, 'متن سؤال و حداقل ۲ گزینه لازم است');
      return;
    }
    final correctIndex = _correctIndex >= opts.length ? 0 : _correctIndex;
    setState(() => _saving = true);
    final row = AdminQuestionRow(
      id: widget.existing?.id ?? 'new',
      examId: widget.examId,
      text: _text.text.trim(),
      options: opts,
      correctIndex: correctIndex,
      orderIndex: widget.existing?.orderIndex ?? 0,
    );
    try {
      await ref.read(saveQuestionUseCaseProvider).call(row);
      ref.invalidate(adminExamQuestionsProvider(widget.examId));
      ref.invalidate(adminExamsProvider);
      if (mounted) {
        Navigator.pop(context);
        _toast(context, 'ذخیره شد');
      }
    } catch (e) {
      if (mounted) _toast(context, 'خطا: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _SheetScaffold(
      title: widget.existing == null ? 'سؤال جدید' : 'ویرایش سؤال',
      onSave: _saving ? () async {} : _save,
      children: [
        _field(_text, 'متن سؤال', maxLines: 2),
        const SizedBox(height: 4),
        Text('گزینه‌ها (پاسخ صحیح را با دکمهٔ رادیویی مشخص کنید)',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...List.generate(4, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Radio<int>(
                  value: i,
                  groupValue: _correctIndex,
                  onChanged: (v) => setState(() => _correctIndex = v ?? 0),
                ),
                Expanded(
                  child: TextField(
                    controller: _opts[i],
                    decoration: InputDecoration(
                      label: Text('گزینهٔ ${i + 1}'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
