import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../core/notifications/notification_route_resolver.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared_models/app_notification.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/notifications_providers.dart';

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
    case NotificationKind.chat:
      return Icons.chat_bubble_rounded;
    case NotificationKind.homework:
      return Icons.edit_note_rounded;
    case NotificationKind.account:
      return Icons.person_rounded;
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
    case NotificationKind.chat:
      return AppColors.orange600;
    case NotificationKind.homework:
      return AppColors.info;
    case NotificationKind.account:
      return AppColors.gold600;
  }
}

String _timeAgo(BuildContext context, DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return context.tr('notifications.justNow');
  if (diff.inMinutes < 60) return context.tr('notifications.minutesAgo', {'count': '${diff.inMinutes}'});
  if (diff.inHours < 24) return context.tr('notifications.hoursAgo', {'count': '${diff.inHours}'});
  if (diff.inDays < 7) return context.tr('notifications.daysAgo', {'count': '${diff.inDays}'});
  return '${d.year}/${d.month}/${d.day}';
}

// کلیدهای داخلیِ گروه‌بندی (پایدار، مستقل از زبان) — برچسبِ نمایشی از
// `_bucketLabel` گرفته می‌شود تا با تغییر زبان هماهنگ بماند.
const _kBucketToday = 'today';
const _kBucketYesterday = 'yesterday';
const _kBucketOlder = 'older';

String _bucketFor(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff <= 0) return _kBucketToday;
  if (diff == 1) return _kBucketYesterday;
  return _kBucketOlder;
}

String _bucketLabel(BuildContext context, String key) {
  switch (key) {
    case _kBucketToday:
      return context.tr('notifications.bucketToday');
    case _kBucketYesterday:
      return context.tr('notifications.bucketYesterday');
    default:
      return context.tr('notifications.bucketOlder');
  }
}

/// صفحهٔ اعلان‌ها.
///
/// رفع اشکال: قبلاً این صفحه فقط `NotificationCenter.instance` (حافظهٔ
/// محلی/همین نشست، بدون اتصال به سرور) را نمایش می‌داد؛ اعلان‌های واقعیِ
/// سرور (مثلاً نمرهٔ امتحان از `exams.ts`، اعلان والدین از `parents.ts`، که
/// در جدول واقعی `notifications` ذخیره می‌شوند) هرگز دیده نمی‌شدند. اکنون
/// این صفحه ابتدا فهرست واقعی سرور را می‌گیرد (`notificationsProvider`) و
/// با `NotificationCenter.ingestServer` با فهرست محلی ادغام می‌کند — هم
/// صحت داده‌های سرور و هم فوریتِ toastهای همین‌نشست (مثل ارتقای صنف) حفظ
/// می‌شود. علامت «خوانده‌شد» برای آیتم‌های با منشأ سرور به backend هم اعلام
/// می‌شود.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  /// رفع اشکال «لمس اعلان هیچ‌جا را باز نمی‌کرد»: مقصد باز شدن هر اعلان بر
  /// اساس `kind` + `relatedId` + نقش کاربر تعیین می‌شود (بخش ۱۳.۱ سند —
  /// ستون `related_id` در migration 0029). اگر مقصد مشخصی نباشد (null)،
  /// لمس فقط اعلان را خوانده‌شده می‌کند (رفتار قبلی).
  // منطق واقعی در `core/notifications/notification_route_resolver.dart`
  // است تا هندلر Push واقعی سیستم‌عامل هم بتواند همان قاعده را استفاده کند.
  String? _routeFor(AppNotification n, AppUserRole role) => resolveNotificationRoute(n.kind, n.relatedId, role);

  Future<void> _openNotification(AppNotification n, AppUserRole role) async {
    // اول مقصد را بگیر و ناوبری کن تا await شدنِ markRead (رفت‌وبرگشت شبکه)
    // باز شدن صفحه را عقب نیندازد.
    final route = _routeFor(n, role);
    if (route != null && mounted) context.push(route);
    await _markRead(n.id);
  }

  Future<void> _markRead(String id) async {
    final center = NotificationCenter.instance;
    final wasServerSourced = center.isServerSourced(id);
    center.markRead(id);
    if (wasServerSourced) {
      await ref.read(markNotificationReadUseCaseProvider).call(id);
    }
  }

  Future<void> _markAllRead(List<AppNotification> items) async {
    final center = NotificationCenter.instance;
    final unreadServerIds = items.where((n) => !n.read && center.isServerSourced(n.id)).map((n) => n.id).toList();
    center.markAllRead();
    for (final id in unreadServerIds) {
      await ref.read(markNotificationReadUseCaseProvider).call(id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = NotificationCenter.instance;

    ref.listen<AsyncValue<List<AppNotification>>>(notificationsProvider, (previous, next) {
      next.whenData((list) => center.ingestServer(list));
    });
    // اگر داده‌های سرور از قبل حاضر است (کش شده)، همین حالا هم ادغام کن.
    ref.watch(notificationsProvider).whenData((list) => center.ingestServer(list));

    // رفع اشکال: قبلاً نقش این صفحه همیشه «شاگرد» بود (کد ثابت) — یعنی اگر
    // والد/استاد هم به این صفحه می‌رسیدند، منوی کناری‌شان به‌جای آیتم‌های
    // خودشان، منوی شاگرد را نشان می‌داد. حالا از نشست واردشدهٔ واقعی گرفته
    // می‌شود.
    final role = ref.watch(authSessionProvider)?.role ?? AppUserRole.student;

    return AppScaffold(
      title: context.tr('notifications.title'),
      role: role,
      actions: [
        AnimatedBuilder(
          animation: center,
          builder: (context, _) => center.unreadCount == 0
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: context.tr('notifications.markAllReadTooltip'),
                  icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                  onPressed: () {
                    _markAllRead(center.items);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.tr('notifications.allMarkedRead')), behavior: SnackBarBehavior.floating),
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
          const order = [_kBucketToday, _kBucketYesterday, _kBucketOlder];
          final sections = order.where(buckets.containsKey).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _header(context, center.unreadCount),
              for (final s in sections) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Text(_bucketLabel(context, s),
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
                ...buckets[s]!.asMap().entries.map((e) => _NotificationCard(
                      n: e.value,
                      onTap: () => _openNotification(e.value, role),
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
                  unread == 0
                      ? context.tr('notifications.noUnread')
                      : context.tr('notifications.unreadCount', {'count': '$unread'}),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
                Text(context.tr('notifications.subtitle'),
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
                      Text(_timeAgo(context, n.createdAt),
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
