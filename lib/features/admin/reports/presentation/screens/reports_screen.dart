import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../providers/reports_providers.dart';

const _iconPalette = [
  AppColors.orange500,
  AppColors.green600,
  AppColors.gold600,
  AppColors.info,
];

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(summaryReportProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('admin.reports'),
      role: AppUserRole.superAdmin,
      body: reportAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
        data: (rows) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = rows[i];
            final color = _iconPalette[i % _iconPalette.length];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                border: Border.all(color: scheme.outlineVariant),
                boxShadow: AppShadows.soft,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Icon(Icons.bar_chart_rounded, color: color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(child: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text(r.value,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
