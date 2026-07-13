import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/curriculum_providers.dart';

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
        error: (e, st) => ErrorView(message: e.toString()),
        data: (lessons) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: lessons.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final lesson = lessons[i];
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
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: lesson.viewed
                              ? scheme.secondaryContainer
                              : scheme.primaryContainer,
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
          },
        ),
      ),
    );
  }
}
