import '../../../../../core/network/api_client.dart';
import '../../domain/entities/safety_queue_item.dart';

/// قرارداد مشترک DataSource صف ایمنی — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class SafetyQueueDataSource {
  Future<List<SafetyQueueItem>> getQueue();
  Future<void> resolve(String id, SafetyItemStatus newStatus);
}

/// پیاده‌سازی واقعی — روتر admin زیر `/api/v1/admin` (بخش ۱۵.۵ سند).
/// موارد ذخیره‌شده + موارد at-risk سنتزشده از فعالیت واقعی سرور.
class SafetyQueueRemoteDataSource implements SafetyQueueDataSource {
  final ApiClient _api;
  SafetyQueueRemoteDataSource(this._api);

  @override
  Future<List<SafetyQueueItem>> getQueue() async {
    final data = await _api.get('/admin/safety-queue');
    final items = (data['items'] as List? ?? []);
    return items
        .map((e) => SafetyQueueItem(
              id: e['id'] as String,
              type: _typeFrom(e['type'] as String?),
              summary: e['summary'] as String? ?? '',
              highPriority: e['highPriority'] == true,
              status: _statusFrom(e['status'] as String?),
              studentName: e['studentName'] as String? ?? '',
              studentGrade: e['studentGrade'] as String? ?? '',
              source: e['source'] as String? ?? '',
              detectedAt: DateTime.tryParse(e['detectedAt'] as String? ?? ''),
              detail: e['detail'] as String? ?? '',
              triggerReason: e['triggerReason'] as String? ?? '',
            ))
        .toList();
  }

  @override
  Future<void> resolve(String id, SafetyItemStatus newStatus) async {
    await _api.patch('/admin/safety-queue/$id/resolve', data: {'status': newStatus.name});
  }

  SafetyItemType _typeFrom(String? s) => SafetyItemType.values.firstWhere(
        (t) => t.name == s,
        orElse: () => SafetyItemType.atRisk,
      );

  SafetyItemStatus _statusFrom(String? s) => SafetyItemStatus.values.firstWhere(
        (t) => t.name == s,
        orElse: () => SafetyItemStatus.open,
      );
}
