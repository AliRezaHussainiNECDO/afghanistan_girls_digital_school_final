import '../../../../shared_models/app_notification.dart';
import 'notifications_remote_datasource.dart' show NotificationsDataSource;

class NotificationsMockDataSource implements NotificationsDataSource {
  final List<AppNotification> _items = [
    AppNotification(
      id: 'n1',
      titleFa: 'درس جدید باز شد',
      bodyFa: 'فصل ۴ ریاضی برای شما باز شد.',
      priority: NotificationPriority.medium,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    AppNotification(
      id: 'n2',
      titleFa: 'یادآوری امتحان',
      bodyFa: 'امتحان ماهانهٔ فزیک فردا ساعت ۹ صبح برگزار می‌شود.',
      priority: NotificationPriority.high,
      createdAt: DateTime.now().subtract(const Duration(hours: 20)),
    ),
    AppNotification(
      id: 'n3',
      titleFa: 'تبریک!',
      bodyFa: 'شما مضمون ادبیات دری را با موفقیت تکمیل کردید.',
      priority: NotificationPriority.low,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      read: true,
    ),
  ];

  @override
  Future<List<AppNotification>> getAll() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.unmodifiable(_items);
  }

  @override
  Future<void> markRead(String id) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx != -1) _items[idx] = _items[idx].copyWith(read: true);
  }
}
