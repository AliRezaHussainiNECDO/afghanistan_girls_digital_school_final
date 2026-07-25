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
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/admin_exam_entities.dart';
import '../../domain/usecases/admin_exams_usecases.dart';
import '../providers/admin_exams_providers.dart';
import '../widgets/admin_exam_forms.dart';
import 'admin_exam_questions_screen.dart';
import '../../../../final_exam/presentation/screens/admin_final_exam_screen.dart';

/// مدیریت امتحانات معمولی (کوییز روزانه/تکلیف/ماهانه) و بانک سؤالاتشان
/// (فقط مدیر). توجه: نوع «امتحان نهایی» در این صفحه دیگر اثری روی ارتقای
/// صنف ندارد — ارتقای واقعی از این پس منحصراً از طریق «امتحانات فاینل»
/// چندمضمونه (آیکن جداگانه در بالای صفحه، `AdminFinalExamScreen`) محاسبه
/// می‌شود؛ به همین دلیل کارت آماری/هشدارِ قدیمیِ «پوشش امتحان نهایی» که
/// بر اساس این جدول محاسبه می‌شد حذف شد تا مدیر را گمراه نکند.
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
      drawer: AppDrawer(role: ref.watch(authSessionProvider)?.role ?? AppUserRole.superAdmin),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr('examAdmin.pageTitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                  // نکته برای هماهنگی: تمایز روشن با «بانک سؤالات تمرینی»ِ
                  // بخش مدیریت محتوا — این‌جا فقط امتحان‌هایی مدیریت می‌شوند
                  // که واقعاً دروازهٔ ارتقای صنف‌اند.
                  Text(context.tr('examAdmin.pageSubtitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              tooltip: context.tr('examAdmin.backTooltip'),
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
        label: Text(context.tr('examAdmin.newExamButton')),
      ),
      body: Column(
        children: [
          // رفع اشکال قابلیت کشف: قبلاً ورودیِ «امتحانات فاینل» فقط یک آیکن
          // کوچکِ بدون برچسب در نوار بالا بود که در میان آیکن‌های زبان/تم
          // گم می‌شد و مدیر اصلاً پیدایش نمی‌کرد. حالا یک بنر واضح و برچسب‌دار
          // بالای فهرست قرار دارد که مستقیم به AdminFinalExamScreen می‌رود.
          _FinalExamManagementBanner(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminFinalExamScreen())),
          ),
          _GradeFilterBar(
            selected: _gradeFilter,
            onSelect: (g) => setState(() => _gradeFilter = g),
          ),
          Expanded(
            child: examsAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(adminExamsProvider),
                  ),
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
                        Text(context.tr('examAdmin.noExamsFound'), style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _ExamCard(exam: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// بنرِ واضح و برچسب‌دار برای ورود به «امتحانات فاینل» چندمضمونهٔ صنف —
/// جایگزین آیکن گمشدهٔ قبلی در نوار بالا.
class _FinalExamManagementBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _FinalExamManagementBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: AppColors.goldCelebrationGradient, borderRadius: BorderRadius.circular(AppRadii.lg)),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 30),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('finalExamAdmin.listTitle'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(context.tr('finalExamAdmin.bannerSubtitle'),
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ],
            ),
          ),
        ),
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
              label: Text(context.tr('examAdmin.allChip')),
              selected: selected == null,
              onSelected: (_) => onSelect(null),
            ),
          ),
          ...kExamGrades.map((g) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(context.tr('bulkImport.gradeOption', {'grade': '$g'})),
                  selected: selected == g,
                  onSelected: (_) => onSelect(g),
                ),
              )),
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
                      context.tr('examAdmin.examSummaryLine', {
                        'grade': context.tr('bulkImport.gradeOption', {'grade': '${exam.gradeNumber}'}),
                        'subject': exam.subjectNameFa,
                        'type': examTypeLabel(context, exam.type),
                        'count': '${exam.questionCount}',
                      }),
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
                child: Text(examStatusLabel(context, exam.status),
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
                        title: Text(ctx.tr('examAdmin.deleteExamTitle')),
                        content: Text(ctx.tr('examAdmin.deleteExamConfirm')),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('common.cancel'))),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(ctx.tr('common.delete')),
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
                  PopupMenuItem(value: 'edit', child: Text(ctx.tr('examAdmin.editMenuItem'))),
                  if (exam.status != ExamAdminStatus.published)
                    PopupMenuItem(value: 'publish', child: Text(ctx.tr('examAdmin.publishMenuItem'))),
                  if (exam.status != ExamAdminStatus.draft)
                    PopupMenuItem(value: 'draft', child: Text(ctx.tr('examAdmin.moveToDraftMenuItem'))),
                  if (exam.status != ExamAdminStatus.closed)
                    PopupMenuItem(value: 'close', child: Text(ctx.tr('examAdmin.closeMenuItem'))),
                  PopupMenuItem(value: 'delete', child: Text(ctx.tr('common.delete'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
