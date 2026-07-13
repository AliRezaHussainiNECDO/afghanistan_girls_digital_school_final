import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/safety_queue_item.dart';
import '../../domain/usecases/safety_queue_usecases.dart';
import '../providers/safety_queue_providers.dart';

IconData _typeIcon(SafetyItemType t) {
  switch (t) {
    case SafetyItemType.chatFlag:
      return Icons.flag_rounded;
    case SafetyItemType.aiEscalation:
      return Icons.smart_toy_rounded;
    case SafetyItemType.chatReport:
      return Icons.report_rounded;
    case SafetyItemType.atRisk:
      return Icons.warning_amber_rounded;
  }
}

String _typeLabel(SafetyItemType t) {
  switch (t) {
    case SafetyItemType.chatFlag:
      return 'پرچم چت';
    case SafetyItemType.aiEscalation:
      return 'ارجاع هوش مصنوعی';
    case SafetyItemType.chatReport:
      return 'گزارش چت';
    case SafetyItemType.atRisk:
      return 'در معرض خطر';
  }
}

String _statusLabel(SafetyItemStatus s) {
  switch (s) {
    case SafetyItemStatus.open:
      return 'در انتظار بررسی';
    case SafetyItemStatus.reviewed:
      return 'بررسی شد';
    case SafetyItemStatus.dismissed:
      return 'رد شد';
    case SafetyItemStatus.escalated:
      return 'ارجاع شد';
  }
}

Color _statusColor(SafetyItemStatus s) {
  switch (s) {
    case SafetyItemStatus.open:
      return AppColors.gold600;
    case SafetyItemStatus.reviewed:
      return AppColors.green600;
    case SafetyItemStatus.dismissed:
      return AppColors.ink500;
    case SafetyItemStatus.escalated:
      return AppColors.danger;
  }
}

String _fmt(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')} '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class SafetyQueueScreen extends ConsumerWidget {
  const SafetyQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(safetyQueueProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('admin.safetyQueue'),
      role: AppUserRole.superAdmin,
      body: queueAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (items) {
          final open = items.where((i) => i.status == SafetyItemStatus.open).length;
          return Column(
            children: [
              // نوار خلاصهٔ وضعیت صف
              Container(
                margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: open > 0
                      ? AppColors.gold600.withValues(alpha: 0.12)
                      : scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: AppColors.gold600.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_moon_rounded, color: AppColors.gold600),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        open > 0 ? '$open مورد در انتظار بازبینی شما' : 'همهٔ موارد بررسی شده‌اند',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return _QueueCard(
                      item: item,
                      onTap: () => _openDetail(context, ref, item),
                    ).animate().fadeIn(delay: (40 * i).ms, duration: 260.ms).slideY(begin: 0.08);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openDetail(BuildContext context, WidgetRef ref, SafetyQueueItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      builder: (_) => _SafetyDetailSheet(item: item, ref: ref),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final SafetyQueueItem item;
  final VoidCallback onTap;
  const _QueueCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: item.highPriority
                ? scheme.errorContainer.withValues(alpha: 0.35)
                : scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
              color: item.highPriority ? scheme.error.withValues(alpha: 0.4) : scheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.highPriority ? scheme.error.withValues(alpha: 0.15) : scheme.surfaceContainerHigh,
                  shape: BoxShape.circle,
                ),
                child: Icon(_typeIcon(item.type),
                    size: 20, color: item.highPriority ? scheme.error : scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.summary, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (item.studentName.isNotEmpty)
                      Text('${item.studentName} · ${item.studentGrade}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _Pill(label: _statusLabel(item.status), color: _statusColor(item.status)),
                        if (item.highPriority) ...[
                          const SizedBox(width: 6),
                          _Pill(label: 'اولویت بالا', color: scheme.error),
                        ],
                      ],
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

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  const _Pill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _SafetyDetailSheet extends StatelessWidget {
  final SafetyQueueItem item;
  final WidgetRef ref;
  const _SafetyDetailSheet({required this.item, required this.ref});

  Future<void> _resolve(BuildContext context, SafetyItemStatus status, String toast) async {
    await ref
        .read(resolveSafetyItemUseCaseProvider)
        .call(ResolveSafetyItemParams(id: item.id, newStatus: status));
    ref.invalidate(safetyQueueProvider);
    if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(toast), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: item.highPriority
                          ? scheme.error.withValues(alpha: 0.15)
                          : scheme.surfaceContainerHigh,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_typeIcon(item.type),
                        color: item.highPriority ? scheme.error : scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_typeLabel(item.type),
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                        Text(item.summary, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Pill(label: _statusLabel(item.status), color: _statusColor(item.status)),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow(context, 'دانش‌آموز', '${item.studentName} · ${item.studentGrade}'),
              _detailRow(context, 'منبع', item.source),
              _detailRow(context, 'زمان ثبت', _fmt(item.detectedAt)),
              _detailRow(context, 'دلیل ثبت در صف', item.triggerReason),
              const SizedBox(height: 4),
              // متن کامل محتوای پرچم‌خورده
              if (item.detail.isNotEmpty) ...[
                Text('محتوای کامل',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(item.detail, style: const TextStyle(height: 1.6)),
                ),
              ],
              const Divider(height: 28),
              // اقدامات مدیر — تنها زمانی که مورد هنوز باز است
              if (item.status == SafetyItemStatus.open)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: AppColors.green600),
                        onPressed: () => _resolve(context, SafetyItemStatus.reviewed, 'مورد بررسی شد'),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('بررسی شد'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: scheme.error),
                        onPressed: () => _resolve(context, SafetyItemStatus.escalated, 'مورد ارجاع شد'),
                        icon: const Icon(Icons.priority_high_rounded, size: 18),
                        label: const Text('ارجاع'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _resolve(context, SafetyItemStatus.dismissed, 'مورد رد شد'),
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('رد کردن'),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _statusColor(item.status).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Text('این مورد قبلاً «${_statusLabel(item.status)}» شده است.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _statusColor(item.status), fontWeight: FontWeight.w700)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    if (value.trim().isEmpty || value.trim() == '·') return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
