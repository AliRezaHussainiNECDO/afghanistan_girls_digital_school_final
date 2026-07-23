/// تب «امتحانات» در پروندهٔ شاگرد (نمای مدیر) — آرشیف کامل امتحانات رسمی
/// شاگرد (کوییز/کارخانگی/ماهانه/نهایی)، به‌صورت فقط‌خواندنی.
///
/// رفع اشکال گزارش‌شده: قبلاً پروندهٔ شاگرد در بخش مدیر فقط اعداد تجمیعی
/// (تعداد امتحان‌ها، میانگین، وضعیت ارتقا) را نشان می‌داد — هیچ راهی برای
/// دیدن تک‌تک امتحان‌ها یا مرور سؤال‌به‌سؤال یک تلاش مشخص نبود. اکنون از
/// همان زیرساخت واقعیِ «نتایج امتحانات» شاگرد استفاده می‌شود
/// (`myExamResultsProvider` → `GET /exams/my-results?studentId=` که برای
/// مدیر مجاز است — بخش routes/exams.ts) — یعنی دقیقاً همان دادهٔ داشبورد
/// شاگرد و داشبورد والدین، بدون هیچ محاسبهٔ جداگانه؛ با لمس هر نتیجه، همان
/// صفحهٔ «مرور پاسخ‌ها»ی مشترک بین همهٔ نقش‌ها باز می‌شود.
library;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/router/app_routes.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../exams/domain/entities/exam_entities.dart';
import '../../../../exams/presentation/providers/exams_providers.dart';
import 'common_widgets.dart';

class AdminStudentExamsTab extends ConsumerWidget {
  final String studentId;
  const AdminStudentExamsTab({super.key, required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(myExamResultsProvider(studentId));

    return resultsAsync.when(
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
            onPressed: () => ref.invalidate(myExamResultsProvider(studentId)),
            icon: const Icon(Icons.refresh),
            label: Text(context.tr('common.retry')),
          ),
        ]),
      ),
      data: (results) {
        final passed = results.where((r) => r.passed).length;
        final avg = results.isEmpty
            ? null
            : results.fold<double>(0, (s, r) => s + r.scorePercent) / results.length;
        final activeFilter = ref.watch(_examsFilterProvider(studentId));
        final filtered = switch (activeFilter) {
          _ExamsFilter.passed => results.where((r) => r.passed).toList(),
          _ExamsFilter.failed => results.where((r) => !r.passed).toList(),
          _ExamsFilter.all => results,
        };

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myExamResultsProvider(studentId)),
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
                    icon: Icons.quiz_rounded,
                    value: '${results.length}',
                    label: context.tr('studentDetail.examsTotalLabel'),
                    color: Colors.indigo,
                  ),
                  StatTile(
                    icon: Icons.workspace_premium_rounded,
                    value: '$passed',
                    label: context.tr('studentDetail.examsPassedLabel'),
                    color: AppPalette.green,
                  ),
                  StatTile(
                    icon: Icons.grade_rounded,
                    value: avg != null ? '٪${avg.toStringAsFixed(0)}' : '—',
                    label: context.tr('studentDetail.examsAvgScoreLabel'),
                    color: AppPalette.amber,
                  ),
                  StatTile(
                    icon: Icons.cancel_rounded,
                    value: '${results.length - passed}',
                    label: context.tr('studentDetail.examsFailedLabel'),
                    color: AppPalette.red,
                  ),
                ],
              ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              _FilterRow(studentId: studentId, activeFilter: activeFilter),
              const SizedBox(height: 16),
              if (filtered.isEmpty)
                _EmptyState(
                  text: results.isEmpty
                      ? context.tr('studentDetail.examsEmptyState')
                      : context.tr('studentDetail.examsFilterEmptyState'),
                )
              else
                for (var i = 0; i < filtered.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ExamResultHistoryCard(result: filtered[i])
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

enum _ExamsFilter { all, passed, failed }

final _examsFilterProvider =
    StateProvider.family<_ExamsFilter, String>((ref, studentId) => _ExamsFilter.all);

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

class _FilterRow extends ConsumerWidget {
  final String studentId;
  final _ExamsFilter activeFilter;
  const _FilterRow({required this.studentId, required this.activeFilter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = <(String, _ExamsFilter, IconData)>[
      (context.tr('homework.filterAll'), _ExamsFilter.all, Icons.apps_rounded),
      (context.tr('studentDetail.examsPassedLabel'), _ExamsFilter.passed, Icons.check_circle_outline_rounded),
      (context.tr('studentDetail.examsFailedLabel'), _ExamsFilter.failed, Icons.highlight_off_rounded),
    ];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, filter, icon) = options[i];
          final selected = activeFilter == filter;
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
              onTap: () => ref.read(_examsFilterProvider(studentId).notifier).state = filter,
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

/// یک ردیف تاریخچه — نوار رنگی سبز/قرمز کنارهٔ کارت وضعیت قبولی را نشان
/// می‌دهد؛ لمس آن همان صفحهٔ «مرور پاسخ‌ها»ی مشترک همهٔ نقش‌ها را باز می‌کند
/// (سؤال‌به‌سؤال، با نشان درست/غلط) — دقیقاً همان چیزی که خودِ شاگرد و
/// والدِ لینک‌شده می‌بینند.
class _ExamResultHistoryCard extends StatelessWidget {
  final ExamResultSummary result;
  const _ExamResultHistoryCard({required this.result});

  String _fmt(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final color = result.passed ? AppPalette.green : AppPalette.red;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(AppRoutes.examResultReview(result.attemptId)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border(right: BorderSide(color: color, width: 4)),
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
                        child: Text(result.subjectNameFa,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppPalette.greenDark)),
                      ),
                      const SizedBox(width: 6),
                      Text(context.tr('homework.classLabel', {'grade': '${result.gradeNumber}'}),
                          style: TextStyle(fontSize: 10.5, color: Colors.grey.shade600)),
                    ]),
                    const SizedBox(height: 8),
                    Text(
                      result.examTitle.isNotEmpty ? result.examTitle : result.subjectNameFa,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, height: 1.4),
                    ),
                    const SizedBox(height: 4),
                    Text(_fmt(result.submittedAt), style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(result.scorePercent.toStringAsFixed(0),
                      style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12.5)),
                ),
                const SizedBox(height: 4),
                Text(
                  result.passed ? context.tr('academy.passedShort') : context.tr('academy.failedShort'),
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color),
                ),
              ]),
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
