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
  static const List<Permission> core = <Permission>[
    Permission.camera,
    Permission.microphone,
    Permission.photos,
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
