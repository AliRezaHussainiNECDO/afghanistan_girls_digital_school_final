import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../providers/curriculum_providers.dart';

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
        data: (chapters) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chapters.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final chapter = chapters[i];
            return Material(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                onTap: () => context.push(AppRoutes.curriculumLessons(subjectId, chapter.id)),
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
                        decoration: BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                        child: Center(
                          child: Text('${chapter.orderIndex}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(chapter.titleFa, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${chapter.lessonCount} ${context.tr('curriculum.lessons')}',
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
          },
        ),
      ),
    );
  }
}
