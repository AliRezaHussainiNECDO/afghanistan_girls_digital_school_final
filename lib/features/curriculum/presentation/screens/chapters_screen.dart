import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../providers/curriculum_providers.dart';
import '../widgets/subject_progress_bar.dart';

/// نمایش فصل‌های یک مضمون با قفل‌گشایی ترتیبی — طبق درخواست کاربر: «هر
/// فصل را تکمیل نکرده، فصل بعدی باز نشود». وضعیت هر فصل (قفل/در حال
/// انجام/تکمیل‌شده) و درصد پیشرفت مستقیماً از همان منطق سرور
/// (`backend/src/lib/progress.ts` → `getChapterList`) می‌آید تا این صفحه
/// منبع واحد پیشرفت درسی برای بقیهٔ داشبوردها (والدین/مدیر) باشد.
class ChaptersScreen extends ConsumerWidget {
  final String subjectId;
  const ChaptersScreen({super.key, required this.subjectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chaptersAsync = ref.watch(chaptersProvider(subjectId));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('curriculum.chapters'))),
      body: chaptersAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (chapters) {
          if (chapters.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'هنوز فصلی برای این مضمون منتشر نشده است.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          }
          // ── رفع ناهماهنگی درصد پیشرفت: قبلاً اینجا میانگین سادهٔ درصد
          // فصل‌ها گرفته می‌شد (هر فصل، صرف‌نظر از تعداد درس‌هایش، وزن
          // یکسان) — اگر فصل‌ها تعداد درس متفاوت داشتند، این عدد با «درصد
          // پیشرفت مضمون» در داشبورد شاگرد/والدین/مدیر (که همه از
          // `getSubjectProgressList` سرور می‌آیند: مجموع درس‌های دیده‌شده ÷
          // مجموع کل درس‌ها) فرق می‌کرد. حالا دقیقاً همان فرمولِ وزن‌دار بر
          // اساس تعداد درسِ هر فصل محاسبه می‌شود تا این عدد در همه‌جای
          // برنامه یکسان باشد.
          final totalLessons = chapters.fold<int>(0, (sum, c) => sum + c.lessonCount);
          final totalViewed = chapters.fold<int>(0, (sum, c) => sum + c.viewedCount);
          final overall = totalLessons > 0 ? (totalViewed / totalLessons) * 100 : 0.0;
          final completedCount = chapters.where((c) => c.completed).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  boxShadow: AppShadows.warm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubjectProgressBar(
                      label: 'پیشرفت کلی این مضمون',
                      percent: overall,
                      light: true,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '$completedCount از ${chapters.length} فصل تکمیل شده',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              for (var i = 0; i < chapters.length; i++) ...[
                _ChapterCard(subjectId: subjectId, chapter: chapters[i])
                    .animate()
                    .fadeIn(delay: (60 * i).ms, duration: 260.ms)
                    .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final String subjectId;
  final Chapter chapter;
  const _ChapterCard({required this.subjectId, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = !chapter.unlocked;
    final completed = chapter.completed;

    Color iconBg;
    Widget iconChild;
    if (locked) {
      iconBg = scheme.surfaceContainerHighest;
      iconChild = Icon(Icons.lock_rounded, color: scheme.onSurfaceVariant, size: 18);
    } else if (completed) {
      iconBg = AppColors.green600;
      iconChild = const Icon(Icons.check_rounded, color: Colors.white, size: 22);
    } else {
      iconBg = scheme.primary;
      iconChild = Text('${chapter.orderIndex}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800));
    }

    return Material(
      color: locked ? scheme.surfaceContainerLowest.withValues(alpha: 0.55) : scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () {
          if (locked) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('برای باز شدن این فصل، ابتدا فصل قبلی را تکمیل کنید.'),
              ),
            );
            return;
          }
          context.push(AppRoutes.curriculumLessons(subjectId, chapter.id));
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: completed ? AppColors.green600.withValues(alpha: 0.4) : scheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Center(child: iconChild),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      chapter.titleFa,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: locked ? scheme.onSurfaceVariant : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      locked
                          ? 'قفل — با تکمیل فصل قبلی باز می‌شود'
                          : (completed
                              ? 'تکمیل شد ✓ (${chapter.lessonCount} درس)'
                              : '${chapter.viewedCount}/${chapter.lessonCount} درس دیده‌شده'),
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                    if (!locked && !completed) ...[
                      const SizedBox(height: 8),
                      SubjectProgressBar(percent: chapter.progressPercent, compact: true),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (completed)
                const Icon(Icons.emoji_events_rounded, color: AppColors.green600, size: 20)
              else if (!locked)
                Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
