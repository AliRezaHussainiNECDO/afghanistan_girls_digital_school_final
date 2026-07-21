import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/attendance_entities.dart';
import '../providers/attendance_providers.dart';

Color _statusColor(AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return AppColors.green500;
    case AttendanceStatus.partial:
      return AppColors.gold600;
    case AttendanceStatus.absent:
      return AppColors.danger;
    case AttendanceStatus.excused:
      return AppColors.info;
  }
}

String _statusLabel(BuildContext context, AttendanceStatus s) {
  switch (s) {
    case AttendanceStatus.present:
      return context.tr('attendance.present');
    case AttendanceStatus.partial:
      return context.tr('attendance.partial');
    case AttendanceStatus.absent:
      return context.tr('attendance.absent');
    case AttendanceStatus.excused:
      return context.tr('attendance.excused');
  }
}

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authSessionProvider);
    final studentId = user?.id ?? 'unknown';
    final summaryAsync = ref.watch(attendanceSummaryProvider(studentId));
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('nav.attendance'),
      role: AppUserRole.student,
      body: summaryAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(attendanceSummaryProvider(studentId)),
            ),
        data: (summary) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.successGradient,
                borderRadius: BorderRadius.circular(AppRadii.xl),
                boxShadow: AppShadows.green,
              ),
              child: Column(
                children: [
                  Text(context.tr('attendance.rate'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('${summary.ratePercent.toStringAsFixed(1)}%',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 34)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: summary.recentDays
                    .map(
                      (day) => Tooltip(
                        message: '${day.date.year}-${day.date.month}-${day.date.day}',
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _statusColor(day.status).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(color: _statusColor(day.status).withValues(alpha: 0.4)),
                          ),
                          child: Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration:
                                  BoxDecoration(color: _statusColor(day.status), shape: BoxShape.circle),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),
            ...AttendanceStatus.values.map(
              (s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: _statusColor(s), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(_statusLabel(context, s)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
