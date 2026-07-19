import '../../../../core/network/api_client.dart';
import '../../../../shared_models/app_notification.dart';

/// قرارداد مشترک DataSource اعلان‌ها — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class NotificationsDataSource {
  Future<List<AppNotification>> getAll();
  Future<void> markRead(String id);
}

/// پیاده‌سازی واقعی — روتر engagement زیر `/api/v1` (بخش ۱۳ سند).
class NotificationsRemoteDataSource implements NotificationsDataSource {
  final ApiClient _api;
  NotificationsRemoteDataSource(this._api);

  @override
  Future<List<AppNotification>> getAll() async {
    final data = await _api.get('/notifications');
    final list = (data['notifications'] as List? ?? []);
    return list.map((n) => AppNotification(
          id: n['id'] as String,
          titleFa: n['titleFa'] as String? ?? '',
          bodyFa: n['bodyFa'] as String? ?? '',
          priority: _priorityFrom(n['priority'] as String?),
          kind: _kindFrom(n['kind'] as String?),
          relatedId: n['relatedId'] as String?,
          createdAt: DateTime.tryParse(n['createdAt'] as String? ?? '') ?? DateTime.now(),
          read: n['read'] == true,
        )).toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _api.patch('/notifications/$id/read');
  }

  NotificationPriority _priorityFrom(String? s) => switch (s) {
        'high' => NotificationPriority.high,
        'low' => NotificationPriority.low,
        _ => NotificationPriority.medium,
      };

  NotificationKind _kindFrom(String? s) => NotificationKind.values.firstWhere(
        (k) => k.name == s,
        orElse: () => NotificationKind.general,
      );
}
