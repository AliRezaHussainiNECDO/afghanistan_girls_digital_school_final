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

/// فهرست درس‌های یک فصل — با «قفل زنجیره‌ای دروس» (Prerequisite Locking):
/// وضعیت باز/قفل هر درس **سرور-محور** است (`backend/src/lib/progress.ts`) و
/// اینجا فقط نمایش داده می‌شود: درس قفل‌شده خاکستری (Disabled) با آیکون 🔒،
/// درس تکمیل‌شده با تیک سبز، و اولین درسِ بازِ تکمیل‌نشده با انیمیشن
/// «باز شدن قفل» (پس از تکمیل درس قبلی) برجسته می‌شود.
class LessonsScreen extends ConsumerWidget {
  final String subjectId;
  final String chapterId;
  const LessonsScreen({super.key, required this.subjectId, required this.chapterId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(lessonsProvider(chapterId));
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('curriculum.lessons'))),
      body: lessonsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
        data: (lessons) {
          if (lessons.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  context.tr('curriculum.noLessonsYet'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            );
          }
          final viewedCount = lessons.where((l) => l.viewed).length;
          final percent = lessons.isEmpty ? 0.0 : (viewedCount / lessons.length) * 100;
          // اولین درسِ باز و تکمیل‌نشده = درسی که تازه (یا الان) باز شده —
          // کاندید انیمیشن «باز شدن قفل».
          final freshlyUnlockedId = lessons
              .where((l) => l.unlocked && !l.completed)
              .map((l) => l.id)
              .cast<String?>()
              .firstWhere((_) => true, orElse: () => null);
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
                    SubjectProgressBar(label: context.tr('curriculum.chapterProgress'), percent: percent, light: true),
                    const SizedBox(height: 10),
                    Text(
                      context.tr('curriculum.lessonsViewedOfCount',
                          {'viewed': '$viewedCount', 'total': '${lessons.length}'}),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
              const SizedBox(height: 16),
              for (var i = 0; i < lessons.length; i++) ...[
                _LessonCard(
                  subjectId: subjectId,
                  chapterId: chapterId,
                  lesson: lessons[i],
                  freshlyUnlocked: lessons[i].id == freshlyUnlockedId,
                )
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

class _LessonCard extends StatelessWidget {
  final String subjectId;
  final String chapterId;
  final Lesson lesson;

  /// این درس همان «درس فعال» زنجیره است — با انیمیشن باز شدن قفل برجسته می‌شود.
  final bool freshlyUnlocked;
  const _LessonCard({
    required this.subjectId,
    required this.chapterId,
    required this.lesson,
    this.freshlyUnlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = !lesson.unlocked;

    // ── ظاهر بر اساس وضعیت زنجیره: قفل (خاکستری) / تکمیل (سبز) / فعال ──
    final Color avatarColor = locked
        ? scheme.surfaceContainerHighest
        : lesson.completed
            ? scheme.secondaryContainer
            : scheme.primaryContainer;
    final Color avatarIconColor = locked
        ? scheme.outline
        : lesson.completed
            ? scheme.onSecondaryContainer
            : scheme.onPrimaryContainer;
    final IconData avatarIcon = locked
        ? Icons.lock_rounded
        : lesson.completed
            ? Icons.check_rounded
            : lesson.viewed
                ? Icons.menu_book_rounded
                : Icons.play_arrow_rounded;

    Widget avatar = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: avatarColor, shape: BoxShape.circle),
      child: Icon(avatarIcon, color: avatarIconColor),
    );
    // انیمیشن «باز شدن قفل» درس تازه‌بازشده — لرزش کوتاه + بزرگ‌نمایی نرم.
    if (freshlyUnlocked && !locked && !lesson.viewed) {
      avatar = avatar
          .animate()
          .scale(
              begin: const Offset(0.6, 0.6),
              end: const Offset(1, 1),
              duration: 450.ms,
              curve: Curves.elasticOut)
          .shimmer(delay: 450.ms, duration: 900.ms);
    }

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Material(
        color: locked ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          onTap: () {
            if (locked) {
              // 🔒 قفل زنجیره‌ای — سرور هم همین را با 403 رد می‌کند؛ اینجا
              // فقط پیام دوستانه نشان داده می‌شود.
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text(context.tr('curriculum.lessonLockedMessage')),
                ));
              return;
            }
            context.push(AppRoutes.curriculumLessonDetail(subjectId, chapterId, lesson.id));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(
                color: locked
                    ? scheme.outlineVariant.withValues(alpha: 0.6)
                    : lesson.completed
                        ? AppColors.green600.withValues(alpha: 0.4)
                        : freshlyUnlocked
                            ? scheme.primary.withValues(alpha: 0.5)
                            : scheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                avatar,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lesson.titleFa,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: locked ? scheme.onSurfaceVariant : null,
                          )),
                      Text(
                        locked
                            ? context.tr('curriculum.lessonLockedSubtitle')
                            : context.tr('curriculum.estimatedMinutes',
                                {'minutes': '${lesson.estimatedMinutes}'}),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (lesson.viewed && !lesson.completed && !locked)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: context.tr('curriculum.homeworkPendingChip'),
                      child: Icon(Icons.history_edu_rounded, size: 20, color: scheme.tertiary),
                    ),
                  ),
                Icon(
                  locked ? Icons.lock_outline_rounded : Icons.chevron_left_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
