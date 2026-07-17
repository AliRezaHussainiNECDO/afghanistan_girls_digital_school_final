import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_drawer.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/language_theme_menu.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/admin_exam_entities.dart';
import '../../domain/usecases/admin_exams_usecases.dart';
import '../providers/admin_exams_providers.dart';
import '../widgets/admin_exam_forms.dart';
import 'admin_exam_questions_screen.dart';

/// مدیریت امتحانات و سؤالات (فقط مدیر) — رفع اشکال: قبلاً هیچ راهی برای
/// ساخت امتحان/سؤال از داخل برنامه وجود نداشت، پس امتحان «نهایی» برای هیچ
/// صنفی هرگز وجود نداشت و سیستم ارتقا عملاً غیرقابل‌دسترس بود.
class AdminExamsScreen extends ConsumerStatefulWidget {
  const AdminExamsScreen({super.key});
  @override
  ConsumerState<AdminExamsScreen> createState() => _AdminExamsScreenState();
}

class _AdminExamsScreenState extends ConsumerState<AdminExamsScreen> {
  int? _gradeFilter;

  @override
  Widget build(BuildContext context) {
    final examsAsync = ref.watch(adminExamsProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(role: AppUserRole.superAdmin),
      backgroundColor: scheme.surface,
      appBar: AppBar(
        toolbarHeight: 72,
        automaticallyImplyLeading: false,
        leadingWidth: 44,
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: AppColors.orange600,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.heroGradient)),
        leading: IconButton(
          tooltip: context.tr('common.back'),
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.canPop() ? context.pop() : context.go(AppRoutes.adminDashboard),
        ),
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: const Icon(Icons.quiz_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text('مدیریت امتحانات',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              tooltip: 'منو',
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          const LanguageThemeMenu(),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExamSheet(context, ExamFormSheet(initialGrade: _gradeFilter)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('امتحان جدید'),
      ),
      body: Column(
        children: [
          _GradeFilterBar(
            selected: _gradeFilter,
            onSelect: (g) => setState(() => _gradeFilter = g),
          ),
          Expanded(
            child: examsAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(message: e.toString()),
              data: (exams) {
                final filtered =
                    _gradeFilter == null ? exams : exams.where((e) => e.gradeNumber == _gradeFilter).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.assignment_outlined,
                            size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        const SizedBox(height: 12),
                        Text('امتحانی یافت نشد', style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                // هشدار: اگر برای این فیلترِ صنف هیچ امتحان «نهایی» منتشرشده
                // وجود نداشته باشد، شاگردان این صنف عملاً نمی‌توانند ارتقا
                // یابند — این پیام مدیر را مستقیماً متوجه این نکته می‌کند.
                final missingFinal = _gradeFilter != null &&
                    !exams.any((e) =>
                        e.gradeNumber == _gradeFilter &&
                        e.type.name == 'finalExam' &&
                        e.status == ExamAdminStatus.published);
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: filtered.length + (missingFinal ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    if (missingFinal && i == 0) {
                      return _MissingFinalWarning(grade: _gradeFilter!);
                    }
                    final e = filtered[i - (missingFinal ? 1 : 0)];
                    return _ExamCard(exam: e);
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

class _GradeFilterBar extends StatelessWidget {
  final int? selected;
  final ValueChanged<int?> onSelect;
  const _GradeFilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: const Text('همه'),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...kExamGrades.map((g) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('صنف $g'),
                  selected: selected == g,
                  onSelected: (_) => onSelect(g),
                ),
              )),
        ],
      ),
    );
  }
}

class _MissingFinalWarning extends StatelessWidget {
  final int grade;
  const _MissingFinalWarning({required this.grade});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'برای صنف $grade هیچ امتحان «نهایی» منتشرشده‌ای وجود ندارد — شاگردان این صنف نمی‌توانند ارتقا یابند.',
              style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamCard extends ConsumerWidget {
  final AdminExamRow exam;
  const _ExamCard({required this.exam});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => AdminExamQuestionsScreen(examId: exam.id, examTitle: exam.title),
        )),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(Icons.quiz_rounded, size: 20, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exam.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      'صنف ${exam.gradeNumber} · ${exam.subjectNameFa} · ${examTypeLabel(context, exam.type)} · ${exam.questionCount} سؤال',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: examStatusColor(exam.status).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: examStatusColor(exam.status).withValues(alpha: 0.4)),
                ),
                child: Text(examStatusLabel(exam.status),
                    style: TextStyle(fontSize: 11, color: examStatusColor(exam.status), fontWeight: FontWeight.w700)),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
                onSelected: (v) async {
                  if (v == 'edit') {
                    showExamSheet(context, ExamFormSheet(existing: exam));
                  } else if (v == 'publish') {
                    await ref.read(setExamStatusUseCaseProvider).call(
                        SetExamStatusParams(id: exam.id, status: ExamAdminStatus.published));
                    ref.invalidate(adminExamsProvider);
                  } else if (v == 'draft') {
                    await ref
                        .read(setExamStatusUseCaseProvider)
                        .call(SetExamStatusParams(id: exam.id, status: ExamAdminStatus.draft));
                    ref.invalidate(adminExamsProvider);
                  } else if (v == 'close') {
                    await ref
                        .read(setExamStatusUseCaseProvider)
                        .call(SetExamStatusParams(id: exam.id, status: ExamAdminStatus.closed));
                    ref.invalidate(adminExamsProvider);
                  } else if (v == 'delete') {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حذف امتحان؟'),
                        content: const Text('همهٔ سؤالات و تلاش‌های ثبت‌شدهٔ این امتحان هم حذف می‌شود.'),
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
                      await ref.read(deleteExamUseCaseProvider).call(exam.id);
                      ref.invalidate(adminExamsProvider);
                    }
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Text('ویرایش')),
                  if (exam.status != ExamAdminStatus.published)
                    const PopupMenuItem(value: 'publish', child: Text('انتشار')),
                  if (exam.status != ExamAdminStatus.draft)
                    const PopupMenuItem(value: 'draft', child: Text('انتقال به پیش‌نویس')),
                  if (exam.status != ExamAdminStatus.closed)
                    const PopupMenuItem(value: 'close', child: Text('بستن')),
                  const PopupMenuItem(value: 'delete', child: Text('حذف')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
