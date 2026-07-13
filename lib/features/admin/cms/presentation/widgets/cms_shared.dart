import 'package:flutter/material.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../domain/entities/cms_entities.dart';

// ─────────────────────── Helpers ───────────────────────
String formatDate(DateTime d) =>
    '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

String difficultyLabel(BuildContext context, String key) {
  switch (key) {
    case 'easy':
      return context.tr('admin.diffEasy');
    case 'hard':
      return context.tr('admin.diffHard');
    case 'medium':
    default:
      return context.tr('admin.diffMedium');
  }
}

String statusLabel(BuildContext context, ContentStatus s) {
  switch (s) {
    case ContentStatus.draft:
      return context.tr('admin.statusDraft');
    case ContentStatus.approved:
      return context.tr('admin.statusApproved');
    case ContentStatus.published:
      return context.tr('admin.statusPublished');
    case ContentStatus.archived:
      return context.tr('admin.statusArchived');
  }
}

Color statusColor(ContentStatus s) {
  switch (s) {
    case ContentStatus.draft:
      return AppColors.ink500;
    case ContentStatus.approved:
      return AppColors.info;
    case ContentStatus.published:
      return AppColors.green600;
    case ContentStatus.archived:
      return AppColors.ink300;
  }
}

/// نمایش یک BottomSheet قابل‌اسکرول و واکنش‌گرا برای فرم‌ها و جزئیات.
Future<void> showCmsSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: child,
    ),
  );
}

// ─────────────────────── Stats strip ───────────────────────
class CmsStatsStrip extends StatelessWidget {
  final List<ContentStatus> statuses;
  const CmsStatsStrip({super.key, required this.statuses});

  @override
  Widget build(BuildContext context) {
    final total = statuses.length;
    final published = statuses.where((s) => s == ContentStatus.published).length;
    final pending = statuses.where((s) => s == ContentStatus.approved).length;
    final drafts = statuses.where((s) => s == ContentStatus.draft).length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        children: [
          _Stat(label: context.tr('admin.statTotal'), value: total, color: AppColors.orange600),
          const SizedBox(width: 10),
          _Stat(label: context.tr('admin.statPublished'), value: published, color: AppColors.green600),
          const SizedBox(width: 10),
          _Stat(label: context.tr('admin.statPending'), value: pending, color: AppColors.info),
          const SizedBox(width: 10),
          _Stat(label: context.tr('admin.statDrafts'), value: drafts, color: AppColors.ink500),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text('$value', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
            Text(label, style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────── Search bar ───────────────────────
class CmsSearchBar extends StatelessWidget {
  final ValueChanged<String> onChanged;
  const CmsSearchBar({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.tr('admin.searchContent'),
          prefixIcon: const Icon(Icons.search_rounded),
          isDense: true,
          filled: true,
          fillColor: scheme.surfaceContainerLowest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            borderSide: BorderSide(color: scheme.outlineVariant),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────── Content card ───────────────────────
class CmsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ContentStatus status;
  final VoidCallback onTap;

  const CmsCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              CmsStatusChip(status: status),
              const SizedBox(width: 4),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class CmsStatusChip extends StatelessWidget {
  final ContentStatus status;
  const CmsStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final c = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(statusLabel(context, status),
          style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

class InviteStatusChip extends StatelessWidget {
  final String status;
  const InviteStatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    Color c;
    String label;
    switch (status) {
      case 'used':
        c = AppColors.info;
        label = 'استفاده‌شده';
        break;
      case 'revoked':
        c = AppColors.danger;
        label = 'باطل‌شده';
        break;
      case 'expired':
        c = AppColors.ink500;
        label = 'منقضی';
        break;
      case 'unused':
      default:
        c = AppColors.green600;
        label = 'استفاده‌نشده';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: c.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w700)),
    );
  }
}

// ─────────────────────── Empty view ───────────────────────
class CmsEmptyView extends StatelessWidget {
  const CmsEmptyView({super.key});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded, size: 56, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(context.tr('admin.noResults'), style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

// ─────────────────────── Detail sheet ───────────────────────
class DetailRow {
  final String label;
  final String value;
  DetailRow(this.label, this.value);
}

class CmsDetailSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final ContentStatus status;
  final List<DetailRow> rows;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;
  final Future<void> Function(ContentStatus) onSetStatus;

  const CmsDetailSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.status,
    required this.rows,
    required this.onEdit,
    required this.onDelete,
    required this.onSetStatus,
  });

  List<(String, ContentStatus, Color)> _transitions(BuildContext context) {
    switch (status) {
      case ContentStatus.draft:
        return [(context.tr('admin.approve'), ContentStatus.approved, AppColors.info)];
      case ContentStatus.approved:
        return [
          (context.tr('admin.publish'), ContentStatus.published, AppColors.green600),
          (context.tr('admin.moveToDraft'), ContentStatus.draft, AppColors.ink500),
        ];
      case ContentStatus.published:
        return [
          (context.tr('admin.archive'), ContentStatus.archived, AppColors.ink500),
          (context.tr('admin.moveToDraft'), ContentStatus.draft, AppColors.ink500),
        ];
      case ContentStatus.archived:
        return [(context.tr('admin.moveToDraft'), ContentStatus.draft, AppColors.info)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final transitions = _transitions(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
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
                    decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                    child: Icon(icon, color: scheme.onPrimaryContainer),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                  const SizedBox(width: 8),
                  CmsStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 16),
              ...rows.where((r) => r.value.trim().isNotEmpty).map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.label,
                            style: TextStyle(
                                fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(r.value, style: const TextStyle(fontSize: 14, height: 1.5)),
                      ],
                    ),
                  )),
              const Divider(height: 24),
              // ── گردش‌کار وضعیت ──
              if (transitions.isNotEmpty) ...[
                Text(context.tr('common.status'),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: transitions
                      .map((t) => FilledButton.tonalIcon(
                            style: FilledButton.styleFrom(
                              backgroundColor: t.$3.withValues(alpha: 0.14),
                              foregroundColor: t.$3,
                            ),
                            onPressed: () async {
                              await onSetStatus(t.$2);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(context.tr('admin.statusChangedOk')),
                                      behavior: SnackBarBehavior.floating),
                                );
                              }
                            },
                            icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                            label: Text(t.$1),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: Text(context.tr('common.edit')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                      ),
                      onPressed: () => _confirmDelete(context),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(context.tr('common.delete')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.tr('admin.deleteConfirm')),
        content: Text(ctx.tr('admin.deleteConfirmMsg')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.tr('common.delete')),
          ),
        ],
      ),
    );
    if (ok == true) {
      await onDelete();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('admin.deletedOk')), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
