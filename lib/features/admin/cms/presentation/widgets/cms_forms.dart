import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../shared_models/subject.dart';
import '../../domain/entities/cms_entities.dart';
import '../providers/cms_providers.dart';

/// ۶ صنفِ ثابت مکتب — هماهنگ با جدول واقعی `grades` سرور (۷ تا ۱۲).
const List<int> _kGrades = [7, 8, 9, 10, 11, 12];

Widget _gradeDropdown(int value, ValueChanged<int> onChanged) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<int>(
      initialValue: _kGrades.contains(value) ? value : _kGrades.first,
      decoration: const InputDecoration(labelText: 'صنف', border: OutlineInputBorder(), isDense: true),
      items: _kGrades.map((g) => DropdownMenuItem(value: g, child: Text('صنف $g'))).toList(),
      onChanged: (v) => onChanged(v ?? _kGrades.first),
    ),
  );
}

Widget _subjectDropdown(String value, ValueChanged<String> onChanged) {
  final valid = mockSubjects.any((s) => s.id == value) ? value : mockSubjects.first.id;
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<String>(
      initialValue: valid,
      decoration: const InputDecoration(labelText: 'مضمون', border: OutlineInputBorder(), isDense: true),
      items: mockSubjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nameFa))).toList(),
      onChanged: (v) => onChanged(v ?? mockSubjects.first.id),
    ),
  );
}

// ─────────────────────── Shared form pieces ───────────────────────
class _FormScaffold extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final Future<void> Function() onSave;
  const _FormScaffold({required this.title, required this.children, required this.onSave});

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

Widget _field(
  TextEditingController c,
  String label, {
  int maxLines = 1,
  TextInputType? keyboard,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    ),
  );
}

Widget _statusDropdown(ContentStatus value, ValueChanged<ContentStatus> onChanged, BuildContext context) {
  // پایه: پیش‌نویس/تأیید/انتشار. اگر مورد در حال ویرایش «بایگانی‌شده» باشد،
  // همان گزینه هم اضافه می‌شود تا مقدار انتخاب‌شده همیشه معتبر بماند
  // (در غیر این صورت Dropdown خطا می‌دهد).
  final items = <DropdownMenuItem<ContentStatus>>[
    DropdownMenuItem(value: ContentStatus.draft, child: Text(context.tr('admin.statusDraft'))),
    DropdownMenuItem(value: ContentStatus.approved, child: Text(context.tr('admin.statusApproved'))),
    DropdownMenuItem(value: ContentStatus.published, child: Text(context.tr('admin.statusPublished'))),
    if (value == ContentStatus.archived)
      DropdownMenuItem(value: ContentStatus.archived, child: Text(context.tr('admin.statusArchived'))),
  ];
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<ContentStatus>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: context.tr('common.status'),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      items: items,
      onChanged: (v) => onChanged(v ?? ContentStatus.draft),
    ),
  );
}

void _saved(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.tr('admin.savedOk')), behavior: SnackBarBehavior.floating),
  );
}

// ═══════════════════════ BOOK FORM ═══════════════════════
class BookFormSheet extends ConsumerStatefulWidget {
  final CmsBookRow? existing;
  const BookFormSheet({super.key, this.existing});
  @override
  ConsumerState<BookFormSheet> createState() => _BookFormSheetState();
}

class _BookFormSheetState extends ConsumerState<BookFormSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _category = TextEditingController(text: widget.existing?.category ?? '');
  late final _author = TextEditingController(text: widget.existing?.author ?? '');
  late final _grade = TextEditingController(text: widget.existing?.grade ?? '');
  late final _chapters = TextEditingController(text: (widget.existing?.chaptersCount ?? '').toString());
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late ContentStatus _status = widget.existing?.status ?? ContentStatus.draft;

  @override
  void dispose() {
    for (final c in [_title, _category, _author, _grade, _chapters, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('admin.requiredField')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final row = CmsBookRow(
      id: widget.existing?.id ?? 'new',
      title: _title.text.trim(),
      category: _category.text.trim(),
      author: _author.text.trim(),
      grade: _grade.text.trim(),
      chaptersCount: int.tryParse(_chapters.text.trim()) ?? 0,
      description: _description.text.trim(),
      status: _status,
      updatedAt: DateTime.now(),
    );
    await ref.read(saveBookUseCaseProvider).call(row);
    ref.invalidate(cmsBooksProvider);
    if (mounted) {
      Navigator.pop(context);
      _saved(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: widget.existing == null ? context.tr('admin.newBook') : context.tr('admin.editBook'),
      onSave: _save,
      children: [
        _field(_title, context.tr('admin.fTitle')),
        _field(_category, context.tr('admin.fCategory')),
        _field(_author, context.tr('admin.fAuthor')),
        _field(_grade, context.tr('admin.fGrade')),
        _field(_chapters, context.tr('admin.fChapters'), keyboard: TextInputType.number),
        _field(_description, context.tr('admin.fDescription'), maxLines: 3),
        _statusDropdown(_status, (v) => setState(() => _status = v), context),
      ],
    );
  }
}

// ═══════════════════════ LESSON FORM ═══════════════════════
class LessonFormSheet extends ConsumerStatefulWidget {
  final CmsLessonRow? existing;
  const LessonFormSheet({super.key, this.existing});
  @override
  ConsumerState<LessonFormSheet> createState() => _LessonFormSheetState();
}

class _LessonFormSheetState extends ConsumerState<LessonFormSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _chapter = TextEditingController(text: widget.existing?.chapterTitle ?? '');
  late final _duration = TextEditingController(text: (widget.existing?.durationMinutes ?? '').toString());
  late final _content = TextEditingController(text: widget.existing?.content ?? '');
  late int _grade = widget.existing?.gradeNumber ?? 7;
  late String _subjectId = widget.existing?.subjectId ?? mockSubjects.first.id;
  late ContentStatus _status = widget.existing?.status ?? ContentStatus.draft;

  @override
  void dispose() {
    for (final c in [_title, _chapter, _duration, _content]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _chapter.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('admin.requiredField')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final row = CmsLessonRow(
      id: widget.existing?.id ?? 'new',
      title: _title.text.trim(),
      gradeNumber: _grade,
      subjectId: _subjectId,
      chapterTitle: _chapter.text.trim(),
      durationMinutes: int.tryParse(_duration.text.trim()) ?? 0,
      content: _content.text.trim(),
      status: _status,
      updatedAt: DateTime.now(),
    );
    await ref.read(saveLessonUseCaseProvider).call(row);
    ref.invalidate(cmsLessonsProvider);
    if (mounted) {
      Navigator.pop(context);
      _saved(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: widget.existing == null ? context.tr('admin.newLesson') : context.tr('admin.editLesson'),
      onSave: _save,
      children: [
        _field(_title, context.tr('admin.fTitle')),
        _gradeDropdown(_grade, (v) => setState(() => _grade = v)),
        _subjectDropdown(_subjectId, (v) => setState(() => _subjectId = v)),
        _field(_chapter, context.tr('admin.fChapter')),
        _field(_duration, context.tr('admin.fDuration'), keyboard: TextInputType.number),
        _field(_content, context.tr('admin.fContent'), maxLines: 4),
        _statusDropdown(_status, (v) => setState(() => _status = v), context),
      ],
    );
  }
}

// ═══════════════════════ QUESTION FORM ═══════════════════════
class QuestionFormSheet extends ConsumerStatefulWidget {
  final CmsQuestionRow? existing;
  const QuestionFormSheet({super.key, this.existing});
  @override
  ConsumerState<QuestionFormSheet> createState() => _QuestionFormSheetState();
}

class _QuestionFormSheetState extends ConsumerState<QuestionFormSheet> {
  late final _text = TextEditingController(text: widget.existing?.text ?? '');
  late final _subject = TextEditingController(text: widget.existing?.subject ?? '');
  late final _options = TextEditingController(text: widget.existing?.options.join('\n') ?? '');
  late final _answer = TextEditingController(text: widget.existing?.answer ?? '');
  late String _difficulty = widget.existing?.difficulty ?? 'medium';
  late String _type = widget.existing?.type ?? 'mcq';
  late ContentStatus _status = widget.existing?.status ?? ContentStatus.draft;

  @override
  void dispose() {
    for (final c in [_text, _subject, _options, _answer]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_text.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('admin.requiredField')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    final opts = _type == 'mcq'
        ? _options.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    final row = CmsQuestionRow(
      id: widget.existing?.id ?? 'new',
      text: _text.text.trim(),
      subject: _subject.text.trim(),
      difficulty: _difficulty,
      type: _type,
      options: opts,
      answer: _answer.text.trim(),
      status: _status,
      updatedAt: DateTime.now(),
    );
    await ref.read(saveQuestionUseCaseProvider).call(row);
    ref.invalidate(cmsQuestionsProvider);
    if (mounted) {
      Navigator.pop(context);
      _saved(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _FormScaffold(
      title: widget.existing == null ? context.tr('admin.newQuestion') : context.tr('admin.editQuestion'),
      onSave: _save,
      children: [
        _field(_text, context.tr('admin.fTitle'), maxLines: 2),
        _field(_subject, context.tr('admin.fSubject')),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _difficulty,
            decoration: InputDecoration(
              labelText: context.tr('admin.fDifficulty'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: 'easy', child: Text(context.tr('admin.diffEasy'))),
              DropdownMenuItem(value: 'medium', child: Text(context.tr('admin.diffMedium'))),
              DropdownMenuItem(value: 'hard', child: Text(context.tr('admin.diffHard'))),
            ],
            onChanged: (v) => setState(() => _difficulty = v ?? 'medium'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: InputDecoration(
              labelText: context.tr('admin.fType'),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            items: [
              DropdownMenuItem(value: 'mcq', child: Text(context.tr('admin.qTypeMcq'))),
              DropdownMenuItem(value: 'essay', child: Text(context.tr('admin.qTypeEssay'))),
            ],
            onChanged: (v) => setState(() => _type = v ?? 'mcq'),
          ),
        ),
        if (_type == 'mcq') _field(_options, context.tr('admin.fOptions'), maxLines: 4),
        _field(_answer, context.tr('admin.fAnswer')),
        _statusDropdown(_status, (v) => setState(() => _status = v), context),
      ],
    );
  }
}
