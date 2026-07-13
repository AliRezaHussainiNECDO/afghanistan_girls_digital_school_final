import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared_models/app_notification.dart';
import '../../../auth/domain/entities/app_user.dart';

IconData _kindIcon(NotificationKind k) {
  switch (k) {
    case NotificationKind.book:
      return Icons.menu_book_rounded;
    case NotificationKind.exam:
      return Icons.assignment_rounded;
    case NotificationKind.grade:
      return Icons.grade_rounded;
    case NotificationKind.seminar:
      return Icons.groups_rounded;
    case NotificationKind.safety:
      return Icons.shield_rounded;
    case NotificationKind.general:
      return Icons.notifications_rounded;
  }
}

Color _kindColor(NotificationKind k) {
  switch (k) {
    case NotificationKind.book:
      return AppColors.orange600;
    case NotificationKind.exam:
      return AppColors.info;
    case NotificationKind.grade:
      return AppColors.green600;
    case NotificationKind.seminar:
      return const Color(0xFF8E5BD0);
    case NotificationKind.safety:
      return AppColors.danger;
    case NotificationKind.general:
      return AppColors.gold600;
  }
}

String _timeAgo(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'همین حالا';
  if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
  if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
  if (diff.inDays < 7) return '${diff.inDays} روز پیش';
  return '${d.year}/${d.month}/${d.day}';
}

String _bucketFor(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return 'امروز';
  if (diff == 1) return 'دیروز';
  return 'قدیمی‌تر';
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final center = NotificationCenter.instance;
    return AppScaffold(
      title: context.tr('notifications.title'),
      role: AppUserRole.student,
      actions: [
        AnimatedBuilder(
          animation: center,
          builder: (context, _) => center.unreadCount == 0
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'خواندن همه',
                  icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                  onPressed: () {
                    center.markAllRead();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('همهٔ اعلان‌ها خوانده شد'), behavior: SnackBarBehavior.floating),
                    );
                  },
                ),
        ),
      ],
      body: AnimatedBuilder(
        animation: center,
        builder: (context, _) {
          final items = center.items;
          if (items.isEmpty) {
            return _empty(context);
          }
          // گروه‌بندی بر اساس زمان.
          final buckets = <String, List<AppNotification>>{};
          for (final n in items) {
            buckets.putIfAbsent(_bucketFor(n.createdAt), () => []).add(n);
          }
          const order = ['امروز', 'دیروز', 'قدیمی‌تر'];
          final sections = order.where(buckets.containsKey).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _header(context, center.unreadCount),
              for (final s in sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(s,
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                ...buckets[s]!.asMap().entries.map((e) => _NotificationCard(
                      n: e.value,
                      onTap: () => center.markRead(e.value.id),
                    ).animate().fadeIn(delay: (30 * e.key).ms, duration: 240.ms).slideX(begin: 0.06)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, int unread) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        boxShadow: AppShadows.warm,
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_active_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unread == 0 ? 'اعلان خوانده‌نشده‌ای نداری' : '$unread اعلان جدید داری',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text('هر چیز تازه در برنامه اینجا نمایش داده می‌شود',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _empty(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_off_rounded, size: 60, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(context.tr('notifications.empty'), style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification n;
  final VoidCallback onTap;
  const _NotificationCard({required this.n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = _kindColor(n.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.lg),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: n.read ? scheme.surfaceContainerLowest : color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: n.read ? scheme.outlineVariant : color.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Icon(_kindIcon(n.kind), color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(n.titleFa,
                                style: TextStyle(fontWeight: n.read ? FontWeight.w600 : FontWeight.w800)),
                          ),
                          if (!n.read)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(n.bodyFa, style: TextStyle(fontSize: 12.5, height: 1.5, color: scheme.onSurfaceVariant)),
                      const SizedBox(height: 6),
                      Text(_timeAgo(n.createdAt),
                          style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
