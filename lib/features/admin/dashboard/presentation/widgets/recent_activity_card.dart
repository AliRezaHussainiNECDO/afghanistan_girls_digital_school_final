import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../admin_management/presentation/providers/admin_management_providers.dart';
import '../../../admin_management/presentation/screens/admin_activity_screen.dart' show ActivityTimeline;

/// «فعالیت اخیر من» — در داشبورد مدیر زیرمجموعه (role='admin' — بخش
/// «مدیریت مدیران») به‌جای بخش KPI کلیِ مکتب/پایش سیستم نشان داده می‌شود؛
/// آمار کل مکتب برای مدیری که مثلاً فقط دسترسی «مدیریت سمینارها» دارد چندان
/// مربوط نیست، ولی دیدن ۵ اقدام اخیر خودش شخصی‌تر و مفیدتر است — از همان
/// [ActivityTimeline] که در «پروندهٔ مدیر» استفاده می‌شود (بدون تکرار کد).
class RecentActivityCard extends ConsumerWidget {
  final String adminId;
  const RecentActivityCard({super.key, required this.adminId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(adminActivityProvider(adminId));
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.timeline_rounded, size: 16, color: scheme.primary),
              const SizedBox(width: 6),
              Text(context.tr('admin.myRecentActivity'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 12),
          activityAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: LoadingView(),
            ),
            error: (e, st) =>
                ErrorView(error: e, onRetry: () => ref.invalidate(adminActivityProvider(adminId))),
            data: (logs) {
              if (logs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(context.tr('admin.activityEmpty'),
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                );
              }
              return ActivityTimeline(logs: logs.take(5).toList());
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.06);
  }
}
