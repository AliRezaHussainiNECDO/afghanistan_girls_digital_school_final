import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/academy_entities.dart';
import '../academy_providers.dart';
import '../widgets/academy_shared.dart';

/// لیست جامع پاسخ‌های ارسالی شاگردان برای مدیر — به‌تفکیک صنف، مضمون،
/// معلومات شاگرد، سؤالات و پاسخ‌ها و نمره.
class AdminSubmissionsScreen extends ConsumerStatefulWidget {
  const AdminSubmissionsScreen({super.key});
  @override
  ConsumerState<AdminSubmissionsScreen> createState() => _AdminSubmissionsScreenState();
}

class _AdminSubmissionsScreenState extends ConsumerState<AdminSubmissionsScreen> {
  int? _grade;
  String? _subject;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(allSubmissionsProvider);
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'پاسخ‌های امتحانات',
      role: AppUserRole.superAdmin,
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (all) {
          if (all.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.fact_check_outlined, size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('هنوز هیچ پاسخی از شاگردان ثبت نشده است',
                      textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                ]),
              ),
            );
          }
          final grades = (all.map((s) => s.gradeId).toSet().toList()..sort());
          final subjects = all.map((s) => s.subject).toSet().toList()..sort();
          final filtered = all
              .where((s) => (_grade == null || s.gradeId == _grade) && (_subject == null || s.subject == _subject))
              .toList();

          return Column(
            children: [
              _summary(context, all),
              _filters(context, grades, subjects),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text('موردی با این فیلتر نیست', style: TextStyle(color: scheme.onSurfaceVariant)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final s = filtered[i];
                          return _SubmissionCard(
                            s: s,
                            onTap: () => showAcademySheet(context, SubmissionDetailSheet(s: s)),
                          ).animate().fadeIn(delay: (30 * i).ms, duration: 240.ms).slideY(begin: 0.06);
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(BuildContext context, List<Submission> all) {
    final avg = all.isEmpty ? 0.0 : all.map((s) => s.scorePercent).reduce((a, b) => a + b) / all.length;
    final passed = all.where((s) => s.passed).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(children: [
        Expanded(child: _stat('کل پاسخ‌ها', '${all.length}', AppColors.orange600)),
        const SizedBox(width: 10),
        Expanded(child: _stat('میانگین', '${avg.toStringAsFixed(0)}٪', AppColors.info)),
        const SizedBox(width: 10),
        Expanded(child: _stat('قبول‌شده', '$passed', AppColors.green600)),
      ]),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Builder(builder: (context) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
        ]),
      );
    });
  }

  Widget _filters(BuildContext context, List<int> grades, List<String> subjects) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _chip('همه صنوف', _grade == null, () => setState(() => _grade = null)),
          ...grades.map((g) => _chip(gradeLabel(g), _grade == g, () => setState(() => _grade = g))),
          const SizedBox(width: 8),
          Container(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(width: 8),
          _chip('همه مضامین', _subject == null, () => setState(() => _subject = null)),
          ...subjects.map((s) => _chip(s, _subject == s, () => setState(() => _subject = s))),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}

class _SubmissionCard extends StatelessWidget {
  final Submission s;
  final VoidCallback onTap;
  const _SubmissionCard({required this.s, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = s.passed ? AppColors.green600 : AppColors.orange600;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.14),
                child: Text('${s.scorePercent.toStringAsFixed(0)}',
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${s.subject} · ${s.gradeLabel} · ${s.answers.length} سؤال',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class SubmissionDetailSheet extends StatelessWidget {
  final Submission s;
  const SubmissionDetailSheet({super.key, required this.s});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = s.passed ? AppColors.green600 : AppColors.orange600;
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
              Row(children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: color.withValues(alpha: 0.14),
                  child: Text('${s.scorePercent.toStringAsFixed(0)}٪',
                      style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.studentName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('${s.subject} · ${s.gradeLabel}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Text('${s.earnedPoints.toStringAsFixed(1)}/${s.totalPoints.toStringAsFixed(0)}',
                    style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ]),
              const Divider(height: 24),
              ...s.answers.asMap().entries.map((e) => _answer(context, e.key + 1, e.value)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answer(BuildContext context, int n, SubmissionAnswer a) {
    final scheme = Theme.of(context).colorScheme;
    final full = a.awardedPoints >= a.maxPoints;
    final partial = a.awardedPoints > 0 && !full;
    final color = full ? AppColors.green600 : (partial ? AppColors.gold600 : AppColors.danger);

    String studentAns;
    switch (a.kind) {
      case QuestionKind.mcq:
        studentAns = a.chosenIndex != null && a.options.isNotEmpty
            ? a.options[a.chosenIndex!.clamp(0, a.options.length - 1).toInt()]
            : '—';
        break;
      case QuestionKind.trueFalse:
        studentAns = a.chosenBool == null ? '—' : (a.chosenBool! ? 'صحیح' : 'غلط');
        break;
      case QuestionKind.essay:
        studentAns = (a.essayText ?? '').isEmpty ? '—' : a.essayText!;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            KindChip(kind: a.kind),
            const Spacer(),
            Text('${a.awardedPoints.toStringAsFixed(1)}/${a.maxPoints.toStringAsFixed(0)}',
                style: TextStyle(color: color, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Text('$n. ${a.questionText}', style: const TextStyle(fontWeight: FontWeight.w700, height: 1.5)),
          const SizedBox(height: 6),
          InfoRow('پاسخ شاگرد', studentAns),
          if (a.kind == QuestionKind.mcq && a.correctIndex != null && a.options.isNotEmpty)
            InfoRow('پاسخ درست', a.options[a.correctIndex!.clamp(0, a.options.length - 1).toInt()]),
          if (a.kind == QuestionKind.trueFalse && a.correctBool != null)
            InfoRow('پاسخ درست', a.correctBool! ? 'صحیح' : 'غلط'),
          if (a.kind == QuestionKind.essay && a.modelAnswer.isNotEmpty) InfoRow('پاسخ نمونه', a.modelAnswer),
          if (a.aiFeedback.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.info),
                const SizedBox(width: 8),
                Expanded(child: Text(a.aiFeedback, style: const TextStyle(fontSize: 12, height: 1.5))),
              ]),
            ),
        ],
      ),
    );
  }
}
