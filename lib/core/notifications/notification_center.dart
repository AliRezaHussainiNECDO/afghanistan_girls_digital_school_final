import 'package:flutter/foundation.dart';
import '../../shared_models/app_notification.dart';

/// مرکز اعلان‌های درون‌برنامه‌ای — یک منبع واحد و زندهٔ اعلان‌ها که هر بخش
/// اپ می‌تواند به آن اعلان جدید «push» کند (مثلاً هنگام انتشار کتاب، ساخت
/// امتحان جدید، یا ثبت نمرهٔ شاگرد) تا بلافاصله (همین نشست) دیده شود. چون
/// یک [ChangeNotifier] است، هر صفحه‌ای که به آن گوش می‌دهد بلافاصله
/// به‌روزرسانی می‌شود.
///
/// رفع اشکال: این مرکز فقط در حافظهٔ برنامه (per-device, per-session) بود و
/// هیچ‌وقت به سرور وصل نمی‌شد — یعنی اعلان‌های واقعی سرور (نمرهٔ امتحان،
/// اعلان والدین و...، از جدول `notifications`) هرگز در این فهرست دیده
/// نمی‌شدند. اکنون [ingestServer] اعلان‌های واقعی سرور را با این فهرست محلی
/// ادغام می‌کند (بدون تکرار) تا هم فوریتِ UX محلی و هم صحتِ داده‌های سرور
/// با هم حفظ شوند. برای هر آیتمی که منشأ سرور دارد، [isServerSourced] آن را
/// علامت می‌زند تا صفحهٔ اعلان‌ها بداند کِی باید backend را هم به‌روز کند.
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

  /// شناسهٔ اعلان‌هایی که منشأ واقعی سرور دارند (برای markRead هوشمند).
  final Set<String> _serverIds = {};

  bool isServerSourced(String id) => _serverIds.contains(id);

  /// فهرست اعلان‌ها از جدید به قدیم.
  List<AppNotification> get items {
    final copy = [..._items]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(copy);
  }

  int get unreadCount => _items.where((n) => !n.read).length;

  int _seq = 0;

  /// افزودن یک اعلان جدید و اطلاع‌رسانی به شنونده‌ها (فقط محلی/همین نشست).
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

  /// ادغام اعلان‌های واقعیِ دریافت‌شده از سرور با فهرست محلی — بدون تکرار
  /// (بر اساس id). حذفِ آیتم محلیِ صرفاً-Seed «خوش‌آمدگویی» وقتی اولین
  /// دستهٔ واقعی سرور می‌رسد، لازم نیست چون id متفاوت دارد.
  void ingestServer(List<AppNotification> serverItems) {
    var changed = false;
    for (final n in serverItems) {
      _serverIds.add(n.id);
      final idx = _items.indexWhere((e) => e.id == n.id);
      if (idx == -1) {
        _items.add(n);
        changed = true;
      } else if (_items[idx].read != n.read) {
        // وضعیت خوانده‌شدن را از سرور (منبع حقیقت) همگام نگه دار.
        _items[idx] = n;
        changed = true;
      }
    }
    if (changed) notifyListeners();
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
    _serverIds.clear();
    notifyListeners();
  }
}
