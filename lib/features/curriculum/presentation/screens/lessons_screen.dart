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
                _LessonCard(subjectId: subjectId, chapterId: chapterId, lesson: lessons[i])
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
  const _LessonCard({required this.subjectId, required this.chapterId, required this.lesson});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () =>
            context.push(AppRoutes.curriculumLessonDetail(subjectId, chapterId, lesson.id)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: lesson.viewed ? AppColors.green600.withValues(alpha: 0.4) : scheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: lesson.viewed ? scheme.secondaryContainer : scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  lesson.viewed ? Icons.check_rounded : Icons.play_arrow_rounded,
                  color: lesson.viewed ? scheme.onSecondaryContainer : scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.titleFa, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      context.tr('curriculum.estimatedMinutes', {'minutes': '${lesson.estimatedMinutes}'}),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
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
