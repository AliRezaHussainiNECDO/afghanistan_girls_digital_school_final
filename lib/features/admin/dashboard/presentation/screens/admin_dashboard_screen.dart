import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../system_health/presentation/widgets/system_health_section.dart';
import '../providers/admin_dashboard_providers.dart';

class _KpiCard extends StatelessWidget {
final IconData icon;
final String label;
final String value;
final Gradient gradient;
const _KpiCard({required this.icon, required this.label, required this.value, required this.gradient});

@override
Widget build(BuildContext context) {
final scheme = Theme.of(context).colorScheme;
return Container(
padding: const EdgeInsets.all(16),
decoration: BoxDecoration(
color: scheme.surfaceContainerLowest,
borderRadius: BorderRadius.circular(AppRadii.lg),
border: Border.all(color: scheme.outlineVariant),
boxShadow: AppShadows.soft,
),
child: Column(
crossAxisAlignment: CrossAxisAlignment.start,
children: [
Container(
width: 44,
height: 44,
decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
child: Icon(icon, color: Colors.white, size: 22),
),
const Spacer(),
Text(value,
style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
const SizedBox(height: 2),
Text(label,
style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
],
),
);
}
}

class AdminDashboardScreen extends ConsumerWidget {
const AdminDashboardScreen({super.key});

@override
Widget build(BuildContext context, WidgetRef ref) {
final statsAsync = ref.watch(adminStatsProvider);

return AppScaffold(
title: context.tr('admin.dashboard'),
role: AppUserRole.superAdmin,
body: ListView(
padding: const EdgeInsets.all(16),
children: [
const SystemHealthSection(),
const SizedBox(height: 16),
statsAsync.when(
loading: () => const LoadingView(),
error: (e, st) => ErrorView(message: e.toString()),
data: (stats) => GridView.count(
shrinkWrap: true,
physics: const NeverScrollableScrollPhysics(),
crossAxisCount: 2,
mainAxisSpacing: 14,
crossAxisSpacing: 14,
childAspectRatio: 1.25,
children: [
_KpiCard(
icon: Icons.groups_rounded,
label: context.tr('admin.totalStudents'),
value: '${stats.totalStudents}',
gradient: AppColors.heroGradient,
),
_KpiCard(
icon: Icons.today_rounded,
label: context.tr('admin.activeToday'),
value: '${stats.activeToday}',
gradient: AppColors.successGradient,
),
_KpiCard(
icon: Icons.warning_amber_rounded,
label: context.tr('admin.atRisk'),
value: '${stats.atRiskCount}',
gradient: const LinearGradient(colors: [AppColors.danger, Color(0xFFB4232A)]),
),
_KpiCard(
icon: Icons.grade_rounded,
label: context.tr('dashboard.overallProgress'),
value: '${stats.avgScorePercent.toStringAsFixed(1)}%',
gradient: AppColors.heroGradientWarm,
),
],
),
),
],
),
);
}
}
