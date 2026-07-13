import 'package:flutter/foundation.dart';
import '../../shared_models/app_notification.dart';

/// مرکز اعلان‌های درون‌برنامه‌ای — یک منبع واحد و زندهٔ اعلان‌ها که هر بخش
/// اپ می‌تواند به آن اعلان جدید «push» کند (مثلاً هنگام انتشار کتاب، ساخت
/// امتحان جدید، یا ثبت نمرهٔ شاگرد). چون یک [ChangeNotifier] است، هر صفحه‌ای
/// که به آن گوش می‌دهد بلافاصله به‌روزرسانی می‌شود.
///
/// در فاز اتصال به Backend، همین‌جا می‌توان اعلان‌های Push واقعی (FCM/APNs)
/// را نیز دریافت و به همین لیست تزریق کرد، بدون تغییر در UI.
class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  final List<AppNotification> _items = [
    AppNotification(
      id: 'seed_welcome',
      titleFa: 'به مکتب دیجیتال خوش آمدید 🌸',
      bodyFa: 'از اینجا آخرین کتاب‌ها، امتحان‌ها و نمرات خود را دنبال کنید.',
      priority: NotificationPriority.low,
      kind: NotificationKind.general,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      read: true,
    ),
  ];

  /// فهرست اعلان‌ها از جدید به قدیم.
  List<AppNotification> get items {
    final copy = [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(copy);
  }

  int get unreadCount => _items.where((n) => !n.read).length;

  int _seq = 0;

  /// افزودن یک اعلان جدید و اطلاع‌رسانی به شنونده‌ها.
  void push({
    required String title,
    required String body,
    NotificationKind kind = NotificationKind.general,
    NotificationPriority priority = NotificationPriority.medium,
  }) {
    _items.insert(
      0,
      AppNotification(
        id: 'nc_${DateTime.now().microsecondsSinceEpoch}_${_seq++}',
        titleFa: title,
        bodyFa: body,
        priority: priority,
        kind: kind,
        createdAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void markRead(String id) {
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1 && !_items[idx].read) {
      _items[idx] = _items[idx].copyWith(read: true);
      notifyListeners();
    }
  }

  void markAllRead() {
    var changed = false;
    for (var i = 0; i < _items.length; i++) {
      if (!_items[i].read) {
        _items[i] = _items[i].copyWith(read: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
  }
}
