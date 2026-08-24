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
  /// نکتهٔ ۲۰ اوت ۲۰۲۶: `Permission.bluetoothConnect` عمداً از این لیست
  /// حذف شد. در جلسهٔ قبلی، بر پایهٔ همبستگی (نه یک stack trace قطعی) به
  /// این نتیجه رسیده بودیم که دیالوگ سیستمی درخواست این مجوز باعث یک
  /// مسابقهٔ شرایط با راه‌اندازی مسیر صدای Jitsi/WebRTC می‌شود. با بررسی
  /// دقیق‌تر (Logcat فیلترشده + بازکاویِ باینری build واقعی) ثابت شد علتِ
  /// واقعیِ کرشِ سمینار روی گوشی‌های واقعی چیز کاملاً دیگری بود: R8 code/
  /// resource shrinking در build های release (رفع کامل در
  /// android/app/build.gradle.kts — isMinifyEnabled=false). چون درخواستِ
  /// این مجوز هرگز علتِ واقعیِ کرش نبود و کاربر نگران طولانی‌شدن بررسیِ
  /// انتشار در Play Store/App Store به‌خاطر آن بود، هم این درخواست و هم
  /// اعلامِ خودِ مجوز در AndroidManifest.xml حذف شدند.
  static const List<Permission> core = <Permission>[
    Permission.camera,
    Permission.microphone,
    Permission.notification,
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
