import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../academy/domain/academy_entities.dart';
import '../../../academy/presentation/academy_providers.dart';
import '../../../academy/presentation/screens/academy_exam_screen.dart';
import '../../../academy/presentation/widgets/academy_shared.dart';

/// امتحانات شاگرد — بر اساس مضمون و صنف (از سؤالات منتشرشدهٔ مدیر). یک شاگرد
/// می‌تواند در چند صنف باشد؛ امتحانات به‌تفکیک صنف گروه‌بندی می‌شوند.
class ExamsScreen extends ConsumerWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final examsAsync = ref.watch(studentExamsProvider);
    final mine = ref.watch(mySubmissionsProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('exams.available'),
      role: AppUserRole.student,
      body: examsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (exams) {
          if (exams.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.assignment_outlined, size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('هنوز امتحانی برای صنوف تو منتشر نشده است',
                      textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                ]),
              ),
            );
          }
          // گروه‌بندی بر اساس صنف.
          final byGrade = <int, List<SubjectExam>>{};
          for (final e in exams) {
            byGrade.putIfAbsent(e.gradeId, () => []).add(e);
          }
          final grades = byGrade.keys.toList()..sort();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              mine.maybeWhen(
                data: (subs) => subs.isEmpty ? const SizedBox.shrink() : _recentResults(context, subs),
                orElse: () => const SizedBox.shrink(),
              ),
              for (final g in grades) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  child: Text(gradeLabel(g),
                      style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface, fontSize: 15)),
                ),
                ...byGrade[g]!.asMap().entries.map((entry) {
                  final exam = entry.value;
                  return _ExamCard(
                    exam: exam,
                    onStart: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => AcademyExamScreen(subject: exam.subject, gradeId: exam.gradeId),
                    )),
                  ).animate().fadeIn(delay: (40 * entry.key).ms, duration: 240.ms).slideY(begin: 0.06);
                }),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _recentResults(BuildContext context, List<Submission> subs) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('نتایج اخیر', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSurface)),
        const SizedBox(height: 8),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: subs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final s = subs[i];
              final color = s.passed ? AppColors.green600 : AppColors.orange600;
              return Container(
                width: 130,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${s.scorePercent.toStringAsFixed(0)}٪',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: color)),
                    Text('${s.subject} · ${s.gradeLabel}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ExamCard extends StatelessWidget {
  final SubjectExam exam;
  final VoidCallback onStart;
  const _ExamCard({required this.exam, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(gradient: AppColors.heroGradientWarm, shape: BoxShape.circle),
            child: const Icon(Icons.assignment_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exam.subject, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('${exam.questionCount} سؤال · ${exam.totalPoints} امتیاز',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: onStart, child: Text(context.tr('exams.start'))),
        ],
      ),
    );
  }
}
