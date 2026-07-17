import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../domain/entities/admin_exam_entities.dart';
import '../providers/admin_exams_providers.dart';
import '../widgets/admin_exam_forms.dart';

/// مدیریت سؤالاتِ یک امتحان — تنها راه واقعیِ افزودن سؤال به جدول
/// `questions` (قبلاً هیچ‌جایی از برنامه این امکان را نداشت).
class AdminExamQuestionsScreen extends ConsumerWidget {
  final String examId;
  final String examTitle;
  const AdminExamQuestionsScreen({super.key, required this.examId, required this.examTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final questionsAsync = ref.watch(adminExamQuestionsProvider(examId));
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(examTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExamSheet(context, ExamQuestionFormSheet(examId: examId)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('سؤال جدید'),
      ),
      body: questionsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (questions) {
          if (questions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.quiz_outlined, size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('هنوز سؤالی افزوده نشده', style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
            itemCount: questions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => _QuestionCard(q: questions[i], examId: examId),
          );
        },
      ),
    );
  }
}

class _QuestionCard extends ConsumerWidget {
  final AdminQuestionRow q;
  final String examId;
  const _QuestionCard({required this.q, required this.examId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(q.text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                onSelected: (v) async {
                  if (v == 'edit') {
                    showExamSheet(context, ExamQuestionFormSheet(examId: examId, existing: q));
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حذف سؤال؟'),
                        content: const Text('این عملیات قابل بازگشت نیست.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    );
                    if (ok == true) {
                      await ref.read(deleteQuestionUseCaseProvider).call(q.id);
                      ref.invalidate(adminExamQuestionsProvider(examId));
                      ref.invalidate(adminExamsProvider);
                    }
                  }
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                  PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...List.generate(q.options.length, (i) {
            final isCorrect = i == q.correctIndex;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(
                    isCorrect ? Icons.check_circle_rounded : Icons.circle_outlined,
                    size: 16,
                    color: isCorrect ? AppColors.green600 : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      q.options[i],
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isCorrect ? FontWeight.w700 : FontWeight.w400,
                        color: isCorrect ? AppColors.green600 : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
