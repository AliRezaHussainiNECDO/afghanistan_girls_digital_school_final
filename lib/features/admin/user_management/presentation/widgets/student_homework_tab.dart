/// تب «کار خانگی» در پروندهٔ شاگرد (نمای مدیر) — کل تاریخچهٔ کار خانگی‌های
/// شاگرد + نمره/بازخورد هوش مصنوعی + گفتگوی او با معلم هوشمند دربارهٔ هر
/// نمره، به‌صورت فقط‌خواندنی (مدیر پیام جدید به‌جای شاگرد ارسال نمی‌کند).
///
/// منطق آینده‌نگر: از همان زیرساخت واقعی «کار خانگی» شاگرد استفاده می‌کند
/// (`adminStudentHomeworksProvider` → `GET /homework?studentId=` که برای
/// مدیر کل تاریخچه را برمی‌گرداند، نه فقط صنف فعلی) — یعنی با هر کار خانگی
/// تازه (چه دستی، چه خودکار از روی درسِ باز شده) و با هر ارتقای صنف شاگرد،
/// این تب بدون هیچ تغییر کد خودش را به‌روز نشان می‌دهد.
library;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/localization/app_localizations.dart';
import '../../../../academy/homework/domain/entities/homework.dart';
import '../../../../academy/homework/presentation/providers/homework_providers.dart';
import 'common_widgets.dart';

/// هر کار خانگیِ نمره‌گرفته امتیاز فعالیت ثابتی می‌دهد — هماهنگ با
/// `POINTS_PER_HOMEWORK_GRADED` در `backend/src/lib/progress.ts`. اینجا فقط
/// برای نمایش «امتیاز کسب‌شده از کار خانگی» به مدیر تکرار شده (نه یک منبع
/// حقیقت جدید)؛ اگر آن مقدار در آینده تغییر کند، همین‌جا هم باید هماهنگ شود.
const int _pointsPerGradedHomework = 15;

class StudentHomeworkTab extends ConsumerWidget {
  final String studentId;
  const StudentHomeworkTab({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeworksAsync = ref.watch(adminStudentHomeworksProvider(studentId));

    return homeworksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => ref.invalidate(adminStudentHomeworksProvider(studentId)),
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('common.retry')),
          ),
        ]),
      ),
      data: (result) {
        final total = result.homeworks.length;
        final graded = result.homeworks.where((h) => h.isGraded).toList();
        final earnedPoints = graded.length * _pointsPerGradedHomework;
        final activeFilter = ref.watch(adminHomeworkStatusFilterProvider(studentId));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminStudentHomeworksProvider(studentId)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 700 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.55,
                children: [
                  StatTile(
                    icon: Icons.assignment_turned_in_rounded,
                    value: '$total',
                    label: context.tr('studentDetail.homeworkTotalLabel'),
                    color: AppPalette.greenDark,
                  ),
                  StatTile(
                    icon: Icons.workspace_premium_rounded,
                    value: '${graded.length}',
                    label: context.tr('studentDetail.homeworkGradedLabel'),
                    color: AppPalette.green,
                  ),
                  StatTile(
                    icon: Icons.grade_rounded,
                    value: result.averageScore != null ? result.averageScore!.toStringAsFixed(0) : '—',
                    label: context.tr('studentDetail.homeworkAvgScoreLabel'),
                    color: AppPalette.amber,
                  ),
                  StatTile(
                    icon: Icons.bolt_rounded,
                    value: '$earnedPoints',
                    label: context.tr('studentDetail.homeworkPointsLabel'),
                    color: Colors.indigo,
                  ),
                ],
              ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              _FilterRow(studentId: studentId, activeFilter: activeFilter),
              const SizedBox(height: 16),
              if (result.homeworks.isEmpty)
                _EmptyState(text: context.tr('studentDetail.homeworkEmptyState'))
              else
                for (var i = 0; i < result.homeworks.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _HomeworkHistoryCard(homework: result.homeworks[i])
                        .animate()
                        .fadeIn(delay: (i * 45).ms, duration: 280.ms)
                        .slideY(begin: 0.08, end: 0, delay: (i * 45).ms, duration: 280.ms, curve: Curves.easeOutCubic),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Column(children: [
          Icon(Icons.assignment_late_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.6)),
        ]),
      );
}

/// نوار فیلتر کپسولی — همان حس پویا/مدرنِ نسخهٔ داشبورد شاگرد، این‌بار با
/// رنگ‌بندی روشن هماهنگ با بقیهٔ پروندهٔ شاگرد (`AppPalette`) به‌جای گرادیان
/// تیرهٔ Sunrise (که با تم روشن این صفحه ناهماهنگ می‌بود).
class _FilterRow extends ConsumerWidget {
  final String studentId;
  final HomeworkStatus? activeFilter;
  const _FilterRow({required this.studentId, required this.activeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = <(String, HomeworkStatus?, IconData)>[
      (context.tr('homework.filterAll'), null, Icons.apps_rounded),
      (context.tr('homework.filterPending'), HomeworkStatus.pending, Icons.edit_note_rounded),
      (context.tr('homework.filterSubmitted'), HomeworkStatus.submitted, Icons.hourglass_top_rounded),
      (context.tr('homework.filterGraded'), HomeworkStatus.graded, Icons.workspace_premium_rounded),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, status, icon) = options[i];
          final selected = activeFilter == status;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? AppPalette.greenDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selected ? Colors.transparent : Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: (selected ? AppPalette.greenDark : Colors.black).withValues(alpha: selected ? 0.22 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => ref.read(adminHomeworkStatusFilterProvider(studentId).notifier).state = status,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: selected ? Colors.white : Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey.shade700,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// یک ردیف تاریخچه — نوار رنگی سمت کنارهٔ کارت وضعیت را نشان می‌دهد، لمس آن
/// شیت جزئیات (سؤال/راهنما/عکس/نمره/گفتگو) را باز می‌کند.
class _HomeworkHistoryCard extends StatelessWidget {
  final Homework homework;
  const _HomeworkHistoryCard({required this.homework});

  Color get _statusColor => switch (homework.status) {
        HomeworkStatus.pending => AppPalette.amber,
        HomeworkStatus.submitted => Colors.blueGrey,
        HomeworkStatus.graded => AppPalette.green,
      };

  @override
  Widget build(BuildContext context) {
    final hw = homework;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => _AdminHomeworkDetailSheet(homework: hw),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(right: BorderSide(color: _statusColor, width: 4)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppPalette.greenDark.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(hw.subjectNameFa,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppPalette.greenDark)),
                      ),
                      const SizedBox(width: 6),
                      Text(context.tr('homework.classLabel', {'grade': '${hw.classLevel}'}),
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      hw.questionText,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (hw.isGraded)
                _ScoreBadge(score: hw.aiScore!)
              else
                _StatusChip(status: hw.status, color: _statusColor),
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final HomeworkStatus status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      HomeworkStatus.pending => context.tr('homework.statusPending'),
      HomeworkStatus.submitted => context.tr('homework.statusSubmitted'),
      HomeworkStatus.graded => context.tr('homework.statusGraded'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}

/// یک نشان دایره‌ای رنگی برای نمره — سبز/کهربایی/قرمز طبق آستانه‌های همان
/// `ScoreBar` مشترک این بخش، تا زبان بصری «نمره» در کل پروندهٔ شاگرد یکسان
/// بماند.
class _ScoreBadge extends StatelessWidget {
  final int score;
  const _ScoreBadge({required this.score});

  Color get _color => score >= 75 ? AppPalette.green : (score >= 50 ? AppPalette.amber : AppPalette.red);

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _color.withValues(alpha: 0.12),
          border: Border.all(color: _color, width: 2),
        ),
        alignment: Alignment.center,
        child: Text('$score', style: TextStyle(color: _color, fontWeight: FontWeight.w900, fontSize: 14)),
      );
}

/// شیت جزئیات یک کار خانگی — سؤال/راهنما، دکمهٔ مشاهدهٔ عکس (اگر ارسال شده)،
/// نمره/بازخورد، و کل گفتگوی شاگرد↔معلم هوشمند به‌صورت فقط‌خواندنی (مدیر
/// پیام جدید نمی‌فرستد چون این گفتگوی خودِ شاگرد با معلم هوشمند است).
class _AdminHomeworkDetailSheet extends ConsumerWidget {
  final Homework homework;
  const _AdminHomeworkDetailSheet({required this.homework});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hw = homework;
    final repliesAsync = hw.isGraded ? ref.watch(homeworkRepliesProvider(hw.id)) : null;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.82,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
              children: [
                Row(children: [
                  Expanded(
                    child: Text(hw.subjectNameFa,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppPalette.greenDark)),
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
                ]),
                Text(context.tr('homework.classLabel', {'grade': '${hw.classLevel}'}),
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppPalette.surface, borderRadius: BorderRadius.circular(14)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hw.questionText, style: const TextStyle(fontSize: 14, height: 1.7, fontWeight: FontWeight.w600)),
                      if (hw.hintText.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppPalette.amber),
                          const SizedBox(width: 6),
                          Expanded(child: Text(hw.hintText, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade700))),
                        ]),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (hw.hasImage)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          insetPadding: const EdgeInsets.all(16),
                          child: InteractiveViewer(
                            child: Image.network(hw.studentImageUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Padding(
                              padding: EdgeInsets.all(24),
                              child: Icon(Icons.broken_image_outlined, size: 48),
                            )),
                          ),
                        ),
                      ),
                      icon: const Icon(Icons.photo_outlined, size: 18),
                      label: Text(context.tr('studentDetail.homeworkViewPhoto')),
                    ),
                  )
                else if (!hw.isGraded)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(context.tr('studentDetail.homeworkNotSubmittedNote'),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                if (hw.isGraded) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppPalette.green.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppPalette.green.withValues(alpha: .3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          _ScoreBadge(score: hw.aiScore!),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              hw.aiFeedback.isNotEmpty ? hw.aiFeedback : context.tr('homework.noFeedbackYet'),
                              style: const TextStyle(fontSize: 13, height: 1.6),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(context.tr('studentDetail.homeworkConversationTitle'),
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  if (repliesAsync != null)
                    repliesAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      ),
                      error: (e, _) => Text('$e', style: const TextStyle(fontSize: 12)),
                      data: (replies) {
                        if (replies.isEmpty) {
                          return Text(context.tr('studentDetail.homeworkNoConversationYet'),
                              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600));
                        }
                        return Column(
                          children: replies.map((r) => _ReadOnlyReplyBubble(reply: r)).toList(),
                        );
                      },
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyReplyBubble extends StatelessWidget {
  final HomeworkReply reply;
  const _ReadOnlyReplyBubble({required this.reply});

  @override
  Widget build(BuildContext context) {
    final isAi = reply.sender == HomeworkReplySender.ai;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(11),
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
              decoration: BoxDecoration(
                color: isAi ? AppPalette.surface : AppPalette.greenDark.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(isAi ? Icons.smart_toy_rounded : Icons.person_rounded,
                        size: 12, color: isAi ? AppPalette.greenDark : Colors.blueGrey),
                    const SizedBox(width: 4),
                    Text(
                      isAi ? context.tr('studentDetail.aiTeacherBadge') : context.tr('studentDetail.studentBadge'),
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(reply.text, style: const TextStyle(fontSize: 13, height: 1.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
