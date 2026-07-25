import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared_models/subject.dart';
import '../../../admin/exams_management/presentation/widgets/admin_exam_forms.dart' show kExamGrades;
import '../../domain/entities/final_exam_entities.dart';
import '../../domain/usecases/admin_final_exam_usecases.dart';
import '../providers/admin_final_exam_providers.dart';

/// مدیریت «امتحان فاینل» چندمضمونهٔ صنف — طبق درخواست صاحب پروژه: یک
/// امتحان واحد برای کل صنف، حداقل ۳ سؤال از هر مضمون (~۳۰ سؤال در مجموع)،
/// قابل ساخت دستی یا با هوش مصنوعی. آرشیف کامل همهٔ امتحانات فاینل ساخته‌شده
/// (هر وضعیتی) همین‌جا قابل مرور است.
class AdminFinalExamScreen extends ConsumerStatefulWidget {
  const AdminFinalExamScreen({super.key});

  @override
  ConsumerState<AdminFinalExamScreen> createState() => _AdminFinalExamScreenState();
}

class _AdminFinalExamScreenState extends ConsumerState<AdminFinalExamScreen> {
  int? _gradeFilter;

  Future<void> _createDialog() async {
    int grade = kExamGrades.first;
    final titleCtrl = TextEditingController(text: 'امتحان فاینل');
    final yearCtrl = TextEditingController(text: '1404-1405');
    final created = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(context.tr('finalExamAdmin.newDialogTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: grade,
                decoration: InputDecoration(labelText: context.tr('common.grade')),
                items: kExamGrades.map((g) => DropdownMenuItem(value: g, child: Text(context.tr('finalExamAdmin.gradeOption', {'grade': '$g'})))).toList(),
                onChanged: (v) => setState(() => grade = v ?? grade),
              ),
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: context.tr('finalExamAdmin.titleLabel'))),
              TextField(controller: yearCtrl, decoration: InputDecoration(labelText: context.tr('finalExamAdmin.yearLabel'))),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.tr('common.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.tr('finalExamAdmin.createButton'))),
          ],
        ),
      ),
    );
    if (created != true) return;
    final result = await ref
        .read(createFinalExamUseCaseProvider)
        .call(CreateFinalExamParams(gradeNumber: grade, academicYear: yearCtrl.text.trim(), title: titleCtrl.text.trim()));
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
      (row) {
        ref.invalidate(adminFinalExamsProvider(_gradeFilter));
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => AdminFinalExamDetailScreen(exam: row)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(adminFinalExamsProvider(_gradeFilter));
    return Scaffold(
      backgroundColor: AppColors.sand50,
      appBar: AppBar(title: Text(context.tr('finalExamAdmin.listTitle')), backgroundColor: Colors.transparent, elevation: 0, foregroundColor: AppColors.ink900),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDialog,
        icon: const Icon(Icons.add),
        label: Text(context.tr('finalExamAdmin.newFab')),
        backgroundColor: AppColors.orange600,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SizedBox(
              width: 160,
              child: DropdownButtonFormField<int?>(
                initialValue: _gradeFilter,
                decoration: InputDecoration(labelText: context.tr('finalExamAdmin.gradeFilterLabel'), isDense: true),
                items: [
                  DropdownMenuItem(value: null, child: Text(context.tr('finalExamAdmin.allGrades'))),
                  ...kExamGrades.map((g) => DropdownMenuItem(value: g, child: Text(context.tr('finalExamAdmin.gradeOption', {'grade': '$g'})))),
                ],
                onChanged: (v) => setState(() => _gradeFilter = v),
              ),
            ),
          ),
          Expanded(
            child: examsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('$e')),
              data: (exams) {
                if (exams.isEmpty) return Center(child: Text(context.tr('finalExamAdmin.noExamsYet')));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: exams.length,
                  itemBuilder: (context, i) {
                    final e = exams[i];
                    final statusColor = switch (e.status) {
                      FinalExamAdminStatus.published => AppColors.green600,
                      FinalExamAdminStatus.closed => AppColors.ink500,
                      FinalExamAdminStatus.draft => AppColors.orange600,
                    };
                    final statusLabel = switch (e.status) {
                      FinalExamAdminStatus.published => context.tr('finalExamAdmin.statusPublished'),
                      FinalExamAdminStatus.closed => context.tr('finalExamAdmin.statusClosed'),
                      FinalExamAdminStatus.draft => context.tr('finalExamAdmin.statusDraft'),
                    };
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md), side: BorderSide(color: AppColors.ink300.withValues(alpha: 0.3))),
                      child: ListTile(
                        title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(context.tr('finalExamAdmin.cardSubtitle',
                            {'grade': '${e.gradeNumber}', 'count': '${e.questionCount}', 'year': e.academicYear})),
                        trailing: Chip(label: Text(statusLabel, style: const TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: statusColor, visualDensity: VisualDensity.compact),
                        onTap: () => Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => AdminFinalExamDetailScreen(exam: e)))
                            .then((_) => ref.invalidate(adminFinalExamsProvider(_gradeFilter))),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AdminFinalExamDetailScreen extends ConsumerStatefulWidget {
  final AdminFinalExamRow exam;
  const AdminFinalExamDetailScreen({super.key, required this.exam});

  @override
  ConsumerState<AdminFinalExamDetailScreen> createState() => _AdminFinalExamDetailScreenState();
}

class _AdminFinalExamDetailScreenState extends ConsumerState<AdminFinalExamDetailScreen> {
  bool _generating = false;

  // رفع اشکال «دکمهٔ تولید با AI برای همیشه در حال چرخیدن می‌ماند»: این
  // درخواست هم‌زمان برای همهٔ مضامین صنف سؤال می‌سازد (ممکن است از
  // زمان‌بندی معمول درخواست‌های شبکه بیشتر طول بکشد)، و قبلاً اگر هر
  // خطای غیرمنتظره‌ای (نه فقط Failure استاندارد) رخ می‌داد، spinner هرگز
  // خاموش نمی‌شد و هیچ پیامی هم نشان داده نمی‌شد. حالا: ۱) این یک درخواست
  // با مهلت طولانی‌تر (۶۰ ثانیه به‌جای پیش‌فرض ۲۰ ثانیه) صدا زده می‌شود،
  // و ۲) با try/finally تضمین می‌شود که _generating همیشه خاموش شود و
  // هر خطایی (حتی استثنای پیش‌بینی‌نشده) پیامی نشان دهد.
  Future<void> _generateWithAi() async {
    setState(() => _generating = true);
    try {
      final result = await ref
          .read(generateFinalExamQuestionsUseCaseProvider)
          .call(GenerateFinalExamQuestionsParams(finalExamId: widget.exam.id, perSubjectCount: 3));
      if (!mounted) return;
      result.fold(
        (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
        (r) {
          ref.invalidate(adminFinalExamQuestionsProvider(widget.exam.id));
          final msg = r.failedSubjects.isEmpty
              ? context.tr('finalExamAdmin.generateSuccessMsg', {'count': '${r.savedCount}'})
              : context.tr('finalExamAdmin.generatePartialMsg', {'count': '${r.savedCount}', 'subjects': r.failedSubjects.join('، ')});
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        },
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  Future<void> _addQuestionDialog() async {
    String subjectId = mockSubjects.first.id;
    String qType = 'mcq';
    final textCtrl = TextEditingController();
    final correctCtrl = TextEditingController();
    final optionCtrls = List.generate(4, (_) => TextEditingController());

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: Text(context.tr('finalExamAdmin.addQuestionDialogTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: subjectId,
                  decoration: InputDecoration(labelText: context.tr('common.subject')),
                  items: mockSubjects.map((s) => DropdownMenuItem(value: s.id, child: Text(s.nameFa))).toList(),
                  onChanged: (v) => setState(() => subjectId = v ?? subjectId),
                ),
                DropdownButtonFormField<String>(
                  initialValue: qType,
                  decoration: InputDecoration(labelText: context.tr('finalExamAdmin.qTypeLabel')),
                  items: [
                    DropdownMenuItem(value: 'mcq', child: Text(context.tr('finalExamAdmin.qTypeMcq'))),
                    DropdownMenuItem(value: 'true_false', child: Text(context.tr('finalExamAdmin.qTypeTrueFalse'))),
                    DropdownMenuItem(value: 'essay', child: Text(context.tr('finalExamAdmin.qTypeEssay'))),
                  ],
                  onChanged: (v) => setState(() => qType = v ?? qType),
                ),
                TextField(controller: textCtrl, decoration: InputDecoration(labelText: context.tr('finalExamAdmin.questionTextLabel')), maxLines: 2),
                if (qType == 'mcq')
                  ...optionCtrls.asMap().entries.map((e) => TextField(
                      controller: e.value,
                      decoration: InputDecoration(labelText: context.tr('finalExamAdmin.optionLabel', {'number': '${e.key + 1}'})))),
                TextField(
                  controller: correctCtrl,
                  decoration: InputDecoration(
                      labelText: qType == 'mcq'
                          ? context.tr('finalExamAdmin.correctIndexMcqLabel')
                          : qType == 'true_false'
                              ? context.tr('finalExamAdmin.correctIndexTfLabel')
                              : context.tr('finalExamAdmin.correctCriteriaLabel')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(context.tr('common.cancel'))),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(context.tr('common.save'))),
          ],
        ),
      ),
    );
    if (saved != true) return;

    final options = qType == 'mcq' ? optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList() : <String>[];
    final correctIndex = qType == 'essay' ? -1 : int.tryParse(correctCtrl.text.trim()) ?? 0;
    final row = AdminFinalExamQuestionRow(
      id: 'new-${DateTime.now().microsecondsSinceEpoch}',
      finalExamId: widget.exam.id,
      subjectId: subjectId,
      qType: QuestionTypeX.fromKey(qType),
      text: textCtrl.text.trim(),
      options: options,
      correctIndex: correctIndex,
      answerText: qType == 'essay' ? correctCtrl.text.trim() : '',
    );
    final result = await ref.read(saveFinalExamQuestionUseCaseProvider).call(row);
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
      (_) => ref.invalidate(adminFinalExamQuestionsProvider(widget.exam.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final questionsAsync = ref.watch(adminFinalExamQuestionsProvider(widget.exam.id));
    return Scaffold(
      backgroundColor: AppColors.sand50,
      appBar: AppBar(
        title: Text(widget.exam.title),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.ink900,
        actions: [
          PopupMenuButton<FinalExamAdminStatus>(
            onSelected: (status) async {
              await ref.read(setFinalExamStatusUseCaseProvider).call(SetFinalExamStatusParams(id: widget.exam.id, status: status));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('finalExamAdmin.statusUpdatedMsg'))));
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: FinalExamAdminStatus.draft, child: Text(context.tr('finalExamAdmin.statusDraft'))),
              PopupMenuItem(value: FinalExamAdminStatus.published, child: Text(context.tr('finalExamAdmin.publishOption'))),
              PopupMenuItem(value: FinalExamAdminStatus.closed, child: Text(context.tr('common.close'))),
            ],
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'ai',
            onPressed: _generating ? null : _generateWithAi,
            icon: _generating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_awesome_rounded),
            label: Text(context.tr('finalExamAdmin.generateAiButton')),
            backgroundColor: AppColors.green600,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'manual',
            onPressed: _addQuestionDialog,
            icon: const Icon(Icons.add),
            label: Text(context.tr('finalExamAdmin.manualQuestionButton')),
            backgroundColor: AppColors.orange600,
          ),
        ],
      ),
      body: questionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('$e')),
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.tr('finalExamAdmin.noQuestionsYet'), textAlign: TextAlign.center)));
          }
          final bySubject = <String, List<AdminFinalExamQuestionRow>>{};
          for (final q in questions) {
            bySubject.putIfAbsent(q.subjectNameFa.isEmpty ? q.subjectId : q.subjectNameFa, () => []).add(q);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
            children: [
              for (final entry in bySubject.entries) ...[
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(context.tr('finalExamAdmin.subjectGroupHeader', {'subject': entry.key, 'count': '${entry.value.length}'}),
                        style: const TextStyle(fontWeight: FontWeight.w800))),
                ...entry.value.map((q) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.sm), side: BorderSide(color: AppColors.ink300.withValues(alpha: 0.25))),
                      child: ListTile(
                        title: Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis),
                        subtitle: Text(q.qType.name),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                          onPressed: () async {
                            await ref.read(deleteFinalExamQuestionUseCaseProvider).call(q.id);
                            ref.invalidate(adminFinalExamQuestionsProvider(widget.exam.id));
                          },
                        ),
                      ),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }
}
