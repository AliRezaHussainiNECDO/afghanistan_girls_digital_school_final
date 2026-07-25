import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../../chat/presentation/widgets/chat_ui_helpers.dart' show relativeTimeFa;
import '../../../audit_logs/domain/entities/audit_log_entry.dart';
import '../../domain/entities/admin_manager.dart';
import '../providers/admin_management_providers.dart';
import '../widgets/activity_style.dart';

/// «پروندهٔ مدیر» — پروفایل + نوار زمانیِ زندهٔ فعالیت یک مدیر زیرمجموعه
/// (یا حتی Super Admin)، از همان جدول audit_logs (فقط با فیلتر actorId).
class AdminActivityScreen extends ConsumerWidget {
  final AdminManager admin;
  const AdminActivityScreen({super.key, required this.admin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(adminActivityProvider(admin.id));
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: admin.name.isEmpty ? admin.email : admin.name,
      // یک مدیر زیرمجموعه هم می‌تواند پروندهٔ خودش را از داشبورد باز کند —
      // نقش واقعی کاربر واردشده تعیین می‌کند منوی کناری کدام است، نه همیشه
      // فرض «Super Admin» (که فقط از لیست «مدیریت مدیران» درست بود).
      role: ref.watch(authSessionProvider)?.role ?? AppUserRole.superAdmin,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminActivityProvider(admin.id)),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _ProfileHeaderCard(admin: admin).animate().fadeIn(duration: 350.ms).slideY(begin: 0.06),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.timeline_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(context.tr('admin.activityTitle'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 14),
            activityAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadingView(),
              ),
              error: (e, st) =>
                  ErrorView(error: e, onRetry: () => ref.invalidate(adminActivityProvider(admin.id))),
              data: (logs) {
                if (logs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(context.tr('admin.activityEmpty'),
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ),
                  );
                }
                return ActivityTimeline(logs: logs);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  final AdminManager admin;
  const _ProfileHeaderCard({required this.admin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.7), width: 2),
                ),
                child: Center(
                  child: Text(
                    admin.name.isNotEmpty ? admin.name.substring(0, 1) : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(admin.name.isEmpty ? admin.email : admin.name,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                    const SizedBox(height: 3),
                    Text(admin.email,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 12.5)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: admin.suspended
                      ? Colors.white.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  admin.suspended ? context.tr('admin.suspended') : context.tr('admin.activateAdmin'),
                  style: TextStyle(
                    color: admin.suspended ? AppColors.danger : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: admin.permissions.isEmpty
                ? [
                    Chip(
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      label: Text(context.tr('admin.permissionsLabel'),
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ]
                : admin.permissions
                    .map((p) => Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white.withValues(alpha: 0.18),
                          side: BorderSide.none,
                          label: Text(context.tr('admin.permission.$p'),
                              style: const TextStyle(color: Colors.white, fontSize: 11)),
                        ))
                    .toList(),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

/// نوار زمانیِ فعالیت — خطِ عمودی متصل‌کننده + نقطهٔ رنگی هر رویداد، با
/// انیمیشن ورودِ پلکانی (Stagger) برای حس «زنده و پویا».
class ActivityTimeline extends StatelessWidget {
  final List<AuditLogEntry> logs;
  const ActivityTimeline({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (var i = 0; i < logs.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: activityActionColor(logs[i]).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: activityActionColor(logs[i]).withValues(alpha: 0.4)),
                    ),
                    child: Icon(activityActionIcon(logs[i].actionType), size: 16, color: activityActionColor(logs[i])),
                  ),
                  if (i != logs.length - 1)
                    Container(width: 2, height: 44, color: scheme.outlineVariant),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 18, top: 4),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                activityActionLabel(context, logs[i].actionType),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                            Text(
                              logs[i].createdAt != null ? relativeTimeFa(context, logs[i].createdAt!) : '',
                              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        if (logs[i].targetTable != null || logs[i].reason != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            [
                              if (logs[i].targetTable != null)
                                '${logs[i].targetTable}${logs[i].targetId != null ? " · ${logs[i].targetId}" : ""}',
                              if (logs[i].reason != null) logs[i].reason!,
                            ].join(' — '),
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(delay: (40 * i).ms, duration: 280.ms)
              .slideX(begin: 0.08, end: 0, delay: (40 * i).ms, duration: 280.ms, curve: Curves.easeOutCubic),
      ],
    );
  }
}
