import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

/// سرویس مدیریت مجوزهای دستگاه (دوربین، میکروفون، گالری، اعلان).
///
/// **امن برای وب:** روی وب هیچ درخواست بومی داده نمی‌شود (kIsWeb) و همیشه
/// true برمی‌گردد تا اپ در مرورگر نشکند. روی موبایل/دسکتاپ از بستهٔ
/// permission_handler استفاده می‌شود.
class PermissionService {
  const PermissionService._();

  /// مجوزهای اصلی که در اولین اجرا از کاربر خواسته می‌شود.
  ///
  /// **چرا Permission.bluetoothConnect این‌جاست:** رفع ریشه‌ای اشکال «اتاق
  /// ویدیوکنفرانس سمینار روی گوشی‌های واقعی (مثلاً سامسونگ) برنامه را
  /// می‌بندد». پیش از این، این مجوز فقط داخل جریان ورود به سمینار
  /// (seminar_room_screen.dart::_ensureCallPermissions) و دقیقاً چند خط قبل
  /// از فراخوانی SDK بومی Jitsi درخواست می‌شد. بررسی Logcat دستگاه واقعی
  /// (سامسونگ Galaxy) نشان داد که در لحظهٔ کرش، آخرین Activity ازسرگرفته‌شده
  /// دقیقاً همان دیالوگ سیستمیِ درخواست مجوز (GrantPermissionsActivity) بوده،
  /// بلافاصله قبل از این‌که کل Task برنامه بسته شود — یعنی خودِ لحظهٔ باز/بسته
  /// شدن آن دیالوگ سیستمی، درست همان لحظه‌ای بود که SDK بومی WebRTC/Jitsi هم
  /// می‌خواست مسیر صدا را با سخت‌افزار واقعی راه‌اندازی کند (رگرسیون/مسابقهٔ
  /// شرایط بین بسته‌شدن دیالوگ مجوز و فراخوانی بومی). با افزودن این مجوز به
  /// لیست «اصلی» که در اولین اجرا (permissions_sheet.dart) از کاربر پرسیده
  /// می‌شود، در بیشترِ قطعی موارد تا زمانی که کاربر وارد سمینار می‌شود این
  /// مجوز از قبل تعیین‌شده است، پس هیچ دیالوگ سیستمی در وسط جریان اتصال به
  /// تماس ظاهر نمی‌شود. درخواست مکملِ داخل _ensureCallPermissions همچنان (به
  /// عنوان یک شبکهٔ ایمنی برای کاربرانی که این نسخه را آپدیت کرده‌اند و هرگز
  /// این بلوک onboarding را با آیتم بلوتوث ندیده‌اند) باقی می‌ماند — نگاه کنید
  /// به توضیح تأخیر settle آن‌جا.
  static const List<Permission> core = <Permission>[
    Permission.camera,
    Permission.microphone,
    Permission.photos,
    Permission.notification,
    Permission.bluetoothConnect,
  ];

  static Future<bool> request(Permission p) async {
    if (kIsWeb) return true;
    try {
      final status = await p.request();
      return status.isGranted || status.isLimited;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<Permission, bool>> requestCore() async {
    final result = <Permission, bool>{};
    for (final p in core) {
      result[p] = await request(p);
    }
    return result;
  }

  static Future<bool> isGranted(Permission p) async {
    if (kIsWeb) return true;
    try {
      return (await p.status).isGranted;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openSettingsPage() async {
    if (kIsWeb) return;
    try {
      await openAppSettings();
    } catch (_) {}
  }
}
