import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../academy/homework/domain/entities/homework.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/parent_entities.dart';
import '../providers/parent_homework_providers.dart';
import '../providers/parent_providers.dart';

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// «کنترول کارخانگی فرزندان» — نمای والد (فقط‌خواندنی، بخش ۱۳ب.۳ سند).
///
/// طبق درخواست صاحب پروژه: والد باید ببیند کارخانگی‌هایی که به هر فرزندش
/// داده شده را **ارسال کرده است یا خیر** — به‌همراه نمره و بازخورد معلم
/// هوشمند اگر نمره داده شده باشد. داده‌ها از همان منبع واحد حقیقتِ بخش
/// «کار خانگی» شاگرد خوانده می‌شوند؛ والد هیچ عملی (ارسال عکس/گفتگو)
/// انجام نمی‌دهد.
class ParentHomeworkScreen extends ConsumerStatefulWidget {
  const ParentHomeworkScreen({super.key});

  @override
  ConsumerState<ParentHomeworkScreen> createState() => _ParentHomeworkScreenState();
}

class _ParentHomeworkScreenState extends ConsumerState<ParentHomeworkScreen> {
  String? _selectedChildId;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(linkedChildrenProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('parent.homework'),
      role: AppUserRole.parent,
      body: childrenAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(linkedChildrenProvider),
            ),
        data: (children) {
          if (children.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.family_restroom_rounded,
                      size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text(context.tr('academy.noLinkedChildrenHint'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant, height: 1.8)),
                ]),
              ),
            );
          }
          if (_selectedChildId == null ||
              !children.any((c) => c.studentId == _selectedChildId)) {
            _selectedChildId = children.first.studentId;
          }
          return Column(
            children: [
              // ── انتخاب فرزند (چندفرزندی — بخش ۱۳ب.۵) ──
              SizedBox(
                height: 56,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final LinkedChild c = children[i];
                    final selected = c.studentId == _selectedChildId;
                    return ChoiceChip(
                      label: Text(c.displayName),
                      selected: selected,
                      avatar: CircleAvatar(
                        radius: 11,
                        backgroundColor:
                            selected ? Colors.white24 : scheme.primaryContainer,
                        child: Text(
                          c.displayName.isNotEmpty ? c.displayName.substring(0, 1) : '?',
                          style: TextStyle(
                            fontSize: 11,
                            color: selected ? Colors.white : scheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      selectedColor: scheme.primary,
                      labelStyle:
                          TextStyle(color: selected ? Colors.white : scheme.onSurface),
                      onSelected: (_) =>
                          setState(() => _selectedChildId = c.studentId),
                    );
                  },
                ),
              ),
              Expanded(child: _ChildHomeworkView(studentId: _selectedChildId!)),
            ],
          );
        },
      ),
    );
  }
}

class _ChildHomeworkView extends ConsumerWidget {
  final String studentId;
  const _ChildHomeworkView({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(parentChildHomeworksProvider(studentId));
    final statsAsync = ref.watch(parentChildHomeworkStatsProvider(studentId));
    final filter = ref.watch(parentHomeworkStatusFilterProvider(studentId));
    final scheme = Theme.of(context).colorScheme;

    return listAsync.when(
      loading: () => const LoadingView(),
      error: (e, st) => ErrorView(
        error: e,
        onRetry: () => ref.invalidate(parentChildHomeworksProvider(studentId)),
      ),
      data: (result) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(parentChildHomeworksProvider(studentId));
          ref.invalidate(parentChildHomeworkStatsProvider(studentId));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ── سربرگ آماری: چند مشق، چند ارسال‌شده، چند ارسال‌نشده ──
            statsAsync.maybeWhen(
              data: (stats) => _StatsHeader(stats: stats)
                  .animate()
                  .fadeIn(duration: 420.ms)
                  .slideY(begin: 0.12, end: 0, duration: 420.ms, curve: Curves.easeOutCubic),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 14),
            // ── فیلتر وضعیت (همان تب‌های بخش کار خانگی شاگرد) ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (label, value) in [
                    (context.tr('homework.filterAll'), null),
                    (context.tr('homework.filterPending'), HomeworkStatus.pending),
                    (context.tr('homework.filterSubmitted'), HomeworkStatus.submitted),
                    (context.tr('homework.filterGraded'), HomeworkStatus.graded),
                  ]) ...[
                    ChoiceChip(
                      label: Text(label),
                      selected: filter == value,
                      selectedColor: scheme.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: filter == value ? Colors.white : scheme.onSurface,
                      ),
                      onSelected: (_) => ref
                          .read(parentHomeworkStatusFilterProvider(studentId).notifier)
                          .state = value,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (result.homeworks.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Column(children: [
                  Icon(Icons.assignment_outlined,
                      size: 44, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  const SizedBox(height: 10),
                  Text(context.tr('parent.homeworkEmpty'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.8)),
                ]),
              ).animate().fadeIn(duration: 320.ms)
            else
              for (var i = 0; i < result.homeworks.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ParentHomeworkCard(homework: result.homeworks[i])
                      .animate()
                      .fadeIn(delay: (60 * i).ms, duration: 340.ms)
                      .slideY(
                          begin: 0.10,
                          end: 0,
                          delay: (60 * i).ms,
                          duration: 340.ms,
                          curve: Curves.easeOutCubic),
                ),
          ],
        ),
      ),
    );
  }
}

/// سربرگ گرادیانی آمار کارخانگی فرزند — کل/ارسال‌شده/ارسال‌نشده/میانگین.
class _StatsHeader extends StatelessWidget {
  final ParentHomeworkStats stats;
  const _StatsHeader({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(context.tr('parent.homeworkIntro'),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      height: 1.6)),
            ),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            _StatCell(
                value: '${stats.total}',
                label: context.tr('parent.homeworkTotal'),
                icon: Icons.list_alt_rounded),
            _StatCell(
                value: '${stats.submitted}',
                label: context.tr('parent.homeworkSubmittedCount'),
                icon: Icons.check_circle_rounded),
            _StatCell(
                value: '${stats.notSubmitted}',
                label: context.tr('parent.homeworkPendingCount'),
                icon: Icons.hourglass_top_rounded,
                highlight: stats.notSubmitted > 0),
            _StatCell(
                value: stats.averageScore != null
                    ? stats.averageScore!.toStringAsFixed(0)
                    : '—',
                label: context.tr('homework.averageScoreShort'),
                icon: Icons.grade_rounded),
          ]),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final bool highlight;
  const _StatCell(
      {required this.value, required this.label, required this.icon, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: highlight ? 0.30 : 0.16),
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: Column(children: [
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9), fontSize: 9.5)),
        ]),
      ),
    );
  }
}

/// کارت فقط‌خواندنی یک کارخانگی برای والد — مضمون، صورت سؤال، وضعیت ارسال
/// (پررنگ‌ترین سیگنال برای والد)، تاریخ‌ها و نمره/بازخورد در صورت نمره‌دهی.
class _ParentHomeworkCard extends StatelessWidget {
  final Homework homework;
  const _ParentHomeworkCard({required this.homework});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hw = homework;
    final (statusLabel, statusColor, statusIcon) = switch (hw.status) {
      HomeworkStatus.pending => (
          context.tr('parent.homeworkNotSubmitted'),
          AppColors.orange600,
          Icons.error_outline_rounded
        ),
      HomeworkStatus.submitted => (
          context.tr('homework.statusSubmitted'),
          AppColors.gold600,
          Icons.hourglass_top_rounded
        ),
      HomeworkStatus.graded => (
          context.tr('homework.statusGraded'),
          AppColors.green600,
          Icons.check_circle_rounded
        ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(
          color: hw.status == HomeworkStatus.pending
              ? AppColors.orange400.withValues(alpha: 0.55)
              : scheme.outlineVariant,
        ),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(statusIcon, color: statusColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hw.subjectNameFa,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(hw.questionText,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.6)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // ── تاریخ‌ها: سپرده‌شده / ارسال‌شده ──
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _DateChip(
                  icon: Icons.calendar_today_rounded,
                  text: _fmtDate(hw.createdAt)),
              if (hw.submittedAt != null)
                _DateChip(
                    icon: Icons.upload_rounded,
                    text: context
                        .tr('parent.homeworkSubmittedAt', {'date': _fmtDate(hw.submittedAt!)})),
            ],
          ),
          // ── نمره + بازخورد معلم هوشمند (در صورت نمره‌دهی) ──
          if (hw.isGraded) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _scoreColor(hw.aiScore!).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.grade_rounded, size: 16, color: _scoreColor(hw.aiScore!)),
                  const SizedBox(width: 6),
                  Text('${hw.aiScore}/100',
                      style: TextStyle(
                          color: _scoreColor(hw.aiScore!),
                          fontWeight: FontWeight.w800,
                          fontSize: 13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(hw.aiFeedback,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 12, height: 1.6)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.green600;
    if (score >= 50) return AppColors.gold600;
    return AppColors.danger;
  }
}

class _DateChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DateChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 13, color: scheme.onSurfaceVariant),
      const SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
    ]);
  }
}
