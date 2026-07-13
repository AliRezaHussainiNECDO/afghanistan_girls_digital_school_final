import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/grade_map_providers.dart';
import '../widgets/subject_status_chip.dart';

/// نمایش نقشهٔ صنوف — طبق بخش ۶ سند. **این صفحه هیچ تصمیمی نمی‌گیرد**؛
/// فقط `GET /students/{id}/grade-map` را می‌خواند و نمایش می‌دهد (بخش ۴/۶.۷).
class GradeMapScreen extends ConsumerWidget {
  const GradeMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final studentId = user?.id ?? 'unknown';
    final gradeMapAsync = ref.watch(gradeMapProvider(studentId));
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('gradeMap.title'),
      role: AppUserRole.student,
      body: gradeMapAsync.when(
        loading: () => const LoadingView(),
        error: (err, st) => ErrorView(
          message: err.toString(),
          onRetry: () => ref.invalidate(gradeMapProvider(studentId)),
        ),
        data: (gradeMap) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(gradeMapProvider(studentId)),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppColors.sunriseGradient,
                  borderRadius: BorderRadius.circular(AppRadii.xl),
                  boxShadow: AppShadows.warm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${context.tr('common.grade')} ${gradeMap.gradeNumber}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      child: LinearProgressIndicator(
                        value: gradeMap.gradeAveragePercent / 100,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        valueColor: const AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${context.tr('dashboard.overallProgress')}: ${gradeMap.gradeAveragePercent.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                        Text(
                          '${context.tr('attendance.rate')}: ${gradeMap.attendanceRatePercent.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ...gradeMap.subjects.map(
                (entry) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.subjectNameFa,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadii.pill),
                              child: LinearProgressIndicator(
                                value: entry.completionPercent / 100,
                                minHeight: 6,
                                backgroundColor: scheme.surfaceContainerHigh,
                              ),
                            ),
                            if (entry.finalScore != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '${context.tr('exams.result')}: ${entry.finalScore!.toStringAsFixed(0)}%',
                                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      SubjectStatusChip(status: entry.status),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
