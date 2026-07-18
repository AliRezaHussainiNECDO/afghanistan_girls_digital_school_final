import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_routes.dart';
import '../../features/auth/domain/entities/app_user.dart';
import '../../features/notifications/presentation/providers/notifications_providers.dart';
import '../../shared_models/app_notification.dart';
import '../notifications/notification_center.dart';

/// زنگ اعلان — یک ویجت مشترک و زنده که در AppBar **همهٔ** داشبوردها (شاگرد،
/// والد، مدیر، استاد) نمایش داده می‌شود. قبلاً هیچ داشبوردی نشانه‌ای از
/// اعلان‌های خوانده‌نشده در سربرگ نداشت — کاربر باید حتماً منوی کشویی را باز
/// می‌کرد تا حتی بفهمد اعلان تازه‌ای هست یا نه؛ و برای داشبورد مدیر حتی مسیری
/// به صفحهٔ اعلان‌ها اصلاً وجود نداشت (رجوع کنید به `app_drawer.dart`/
/// `app_routes.dart`).
///
/// این ویجت هر ۲۵ ثانیه (وقتی صفحه‌ای که در آن قرار دارد فعال است) فهرست
/// واقعی سرور را دوباره می‌خواند و با [NotificationCenter] ادغام می‌کند —
/// دقیقاً همان کاری که `NotificationsScreen` هنگام باز شدن انجام می‌دهد — تا
/// بج شمارنده روی داشبورد هم زنده/به‌روز بماند، نه فقط داخل خودِ صفحهٔ اعلان‌ها.
class NotificationBell extends ConsumerStatefulWidget {
  final AppUserRole role;
  const NotificationBell({super.key, required this.role});

  @override
  ConsumerState<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<NotificationBell> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!mounted) return;
      ref.invalidate(notificationsProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _targetRoute {
    switch (widget.role) {
      case AppUserRole.superAdmin:
        return AppRoutes.adminNotifications;
      case AppUserRole.parent:
        return AppRoutes.parentNotifications;
      case AppUserRole.seminarInstructor:
        return AppRoutes.instructorNotifications;
      case AppUserRole.student:
        return AppRoutes.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    // هر بار سرور پاسخ تازه داد (چه از تایمر بالا، چه از کش اولیهٔ Riverpod)،
    // بلافاصله با فهرست محلی/زندهٔ NotificationCenter ادغام می‌شود.
    ref.listen<AsyncValue<List<AppNotification>>>(notificationsProvider, (previous, next) {
      next.whenData(NotificationCenter.instance.ingestServer);
    });
    ref.watch(notificationsProvider).whenData(NotificationCenter.instance.ingestServer);

    // وقتی خودِ کاربر همین حالا داخل یکی از صفحات اعلان‌هاست، نمایش دوبارهٔ
    // زنگ لازم نیست (اضافی و کمی گمراه‌کننده است).
    String currentRoute = '';
    try {
      currentRoute = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      // صفحاتی که با Navigator.push باز شده‌اند GoRouterState ندارند.
    }
    if (currentRoute == _targetRoute) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: NotificationCenter.instance,
      builder: (context, _) {
        final unread = NotificationCenter.instance.unreadCount;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context.push(_targetRoute),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _bellIcon(unread),
                      if (unread > 0)
                        Positioned(
                          top: -3,
                          right: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5484D),
                              shape: unread > 9 ? BoxShape.rectangle : BoxShape.circle,
                              borderRadius: unread > 9 ? BorderRadius.circular(9) : null,
                              border: Border.all(color: Colors.white, width: 1.4),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              unread > 99 ? '99+' : '$unread',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                height: 1,
                              ),
                            ),
                          )
                              .animate(key: ValueKey('badge_$unread'))
                              .scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 420.ms)
                              .then()
                              .shimmer(duration: 1200.ms, delay: 300.ms, color: Colors.white.withValues(alpha: 0.5)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// آیکن زنگ — وقتی اعلان خوانده‌نشده‌ای هست پر و لرزان است، وگرنه ثابت و
  /// توخالی. لرزش فقط زمانی پخش می‌شود که واقعاً چیزی برای دیدن هست، نه در
  /// هر بازسازی صفحه.
  Widget _bellIcon(int unread) {
    final icon = Icon(
      unread > 0 ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
      color: Colors.white,
      size: 24,
    );
    if (unread == 0) return icon;
    return icon
        .animate(key: ValueKey('bell_$unread'))
        .shake(hz: 2.2, offset: const Offset(3, 0), duration: 420.ms);
  }
}
