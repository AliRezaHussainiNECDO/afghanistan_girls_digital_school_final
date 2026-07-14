import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../domain/entities/system_health.dart';
import '../providers/system_health_providers.dart';

class SystemHealthSection extends ConsumerStatefulWidget {
  const SystemHealthSection({super.key});

  @override
  ConsumerState<SystemHealthSection> createState() => _SystemHealthSectionState();
}

class _SystemHealthSectionState extends ConsumerState<SystemHealthSection> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      if (ref.read(systemHealthAutoRefreshProvider)) {
        ref.invalidate(systemHealthProvider);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final healthAsync = ref.watch(systemHealthProvider);
    final autoRefresh = ref.watch(systemHealthAutoRefreshProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.soft,
        border: Border.all(color: AppColors.sand100, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: const Icon(Icons.health_and_safety_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('admin.systemHealth.title'),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.ink900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr('admin.systemHealth.subtitle'),
                      style: const TextStyle(fontSize: 13, color: AppColors.ink500),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: autoRefresh
                    ? context.tr('admin.systemHealth.autoRefreshOn')
                    : context.tr('admin.systemHealth.autoRefreshOff'),
                icon: Icon(
                  autoRefresh ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                  color: autoRefresh ? AppColors.green600 : AppColors.ink500,
                ),
                onPressed: () {
                  ref.read(systemHealthAutoRefreshProvider.notifier).state = !autoRefresh;
                },
              ),
              IconButton(
                tooltip: context.tr('admin.systemHealth.refreshNow'),
                icon: const Icon(Icons.refresh_rounded, color: AppColors.ink700),
                onPressed: () => ref.invalidate(systemHealthProvider),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          healthAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            ),
            error: (err, st) => _ErrorBanner(
              message: err.toString(),
              onRetry: () => ref.invalidate(systemHealthProvider),
            ),
            data: (health) => _HealthContent(health: health),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.danger),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('admin.systemHealth.unreachable'),
                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: AppColors.danger.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(context.tr('admin.systemHealth.retry')),
          ),
        ],
      ),
    );
  }
}

class _HealthContent extends StatelessWidget {
  final SystemHealth health;
  const _HealthContent({required this.health});

  @override
  Widget build(BuildContext context) {
    final statusColor = _overallColor(health.overallStatus);
    final statusLabel = _overallLabel(context, health.overallStatus);
    final time = health.timestamp;
    final timeStr =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.4, duration: 900.ms),
            const SizedBox(width: AppSpacing.sm),
            Text(
              statusLabel,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: statusColor),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.tr('admin.systemHealth.lastChecked', {'time': timeStr}),
                style: const TextStyle(fontSize: 12, color: AppColors.ink500),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: health.checks.map((c) => _CheckChip(check: c)).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _copyReport(context, health),
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(context.tr('admin.systemHealth.copyReport')),
          ),
        ),
      ],
    );
  }

  void _copyReport(BuildContext context, SystemHealth health) {
    final buffer = StringBuffer();
    buffer.writeln('Afghanistan Girls Digital School - System Health Report');
    buffer.writeln('Timestamp: ${health.timestamp.toIso8601String()}');
    buffer.writeln('Overall status: ${health.overallStatus.name}');
    buffer.writeln('---');
    for (final c in health.checks) {
      buffer.writeln(
        '${c.id}: ${c.status.name}${c.latencyMs != null ? ' (${c.latencyMs}ms)' : ''}${c.detailEn != null ? ' - ${c.detailEn}' : ''}',
      );
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('admin.systemHealth.reportCopied'))),
    );
  }

  Color _overallColor(SystemOverallStatus status) {
    switch (status) {
      case SystemOverallStatus.operational:
        return AppColors.green600;
      case SystemOverallStatus.degraded:
        return AppColors.gold600;
      case SystemOverallStatus.down:
        return AppColors.danger;
    }
  }

  String _overallLabel(BuildContext context, SystemOverallStatus status) {
    switch (status) {
      case SystemOverallStatus.operational:
        return context.tr('admin.systemHealth.statusOperational');
      case SystemOverallStatus.degraded:
        return context.tr('admin.systemHealth.statusDegraded');
      case SystemOverallStatus.down:
        return context.tr('admin.systemHealth.statusDown');
    }
  }
}

class _CheckChip extends StatelessWidget {
  final ServiceCheck check;
  const _CheckChip({required this.check});

  @override
  Widget build(BuildContext context) {
    final meta = _checkMeta(check.id);
    final color = _statusColor(check.status);
    final detail = context.isRtl ? check.detailFa : check.detailEn;

    return Tooltip(
      message: detail ?? meta.$2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(meta.$1, size: 15, color: color),
            const SizedBox(width: 6),
            Text(
              meta.$2,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color),
            ),
            if (check.latencyMs != null) ...[
              const SizedBox(width: 4),
              Text(
                '${check.latencyMs}ms',
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.75)),
              ),
            ],
            const SizedBox(width: 6),
            Icon(
              check.status == ServiceCheckStatus.ok
                  ? Icons.check_circle_rounded
                  : check.status == ServiceCheckStatus.warning
                      ? Icons.warning_rounded
                      : Icons.error_rounded,
              size: 14,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(ServiceCheckStatus status) {
    switch (status) {
      case ServiceCheckStatus.ok:
        return AppColors.green600;
      case ServiceCheckStatus.warning:
        return AppColors.gold600;
      case ServiceCheckStatus.error:
        return AppColors.danger;
    }
  }

  (IconData, String) _checkMeta(String id) {
    switch (id) {
      case 'api':
        return (Icons.dns_rounded, 'API');
      case 'database':
        return (Icons.storage_rounded, 'Database');
      case 'storage':
        return (Icons.cloud_rounded, 'Storage');
      case 'auth':
        return (Icons.lock_rounded, 'Auth');
      case 'aiTeacher':
        return (Icons.smart_toy_rounded, 'AI Teacher');
      case 'email':
        return (Icons.email_rounded, 'Email');
      case 'liveStream':
        return (Icons.live_tv_rounded, 'Live Stream');
      default:
        return (Icons.hub_rounded, id);
    }
  }
}
