import 'package:flutter/widgets.dart';

/// کلید سراسری Navigator ریشه — برای ناوبری از بیرونِ درخت ویجت (مثلاً وقتی
/// کاربر روی یک Push Notification سیستم‌عامل لمس می‌کند و اپ از پس‌زمینه/حالت
/// کاملاً بسته باز می‌شود؛ در آن لحظه هیچ `BuildContext` ویجتی در دسترس
/// نیست). به `GoRouter(navigatorKey: rootNavigatorKey, ...)` در
/// `app_router.dart` وصل می‌شود.
final rootNavigatorKey = GlobalKey<NavigatorState>();
