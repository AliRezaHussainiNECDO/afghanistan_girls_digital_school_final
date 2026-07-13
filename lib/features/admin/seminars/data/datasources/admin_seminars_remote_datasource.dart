import '../../../../../core/network/api_client.dart';
import '../../../../../shared_models/seminar.dart';
import '../../../../seminars/data/datasources/seminars_remote_datasource.dart'
    show seminarFromJson;

/// قرارداد مشترک DataSource مدیریت سمینار (Super Admin) — Mock و Remote هر
/// دو آن را پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class AdminSeminarsDataSource {
  Future<List<Seminar>> getAll();
  Future<void> create({
    required String title,
    required String description,
    String? instructorId,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience,
    String meetingLink,
  });
  Future<void> update({
    required String id,
    required String title,
    required String description,
    String? instructorId,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    required SeminarStatus status,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink,
  });
  Future<void> delete(String id);
  Future<void> setStatus(String id, SeminarStatus status);
}

/// پیاده‌سازی واقعی — روتر seminars زیر `/api/v1` (مدیر همهٔ سمینارها را می‌بیند).
class AdminSeminarsRemoteDataSource implements AdminSeminarsDataSource {
  final ApiClient _api;
  AdminSeminarsRemoteDataSource(this._api);

  @override
  Future<List<Seminar>> getAll() async {
    // بدون audience/instructor → سرور همهٔ سمینارها را برمی‌گرداند.
    final data = await _api.get('/seminars');
    final list = (data['seminars'] as List? ?? []);
    return list.map(seminarFromJson).toList();
  }

  @override
  Future<void> create({
    required String title,
    required String description,
    String? instructorId,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience = SeminarAudience.students,
    String meetingLink = '',
  }) async {
    await _api.post('/seminars', data: {
      'title': title,
      'description': description,
      if (instructorId != null && instructorId.isNotEmpty) 'instructorId': instructorId,
      'instructorName': instructorName,
      'scheduledStart': scheduledStart.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      if (capacity != null) 'capacity': capacity,
      'audience': audience.name,
      'meetingLink': meetingLink,
    });
  }

  @override
  Future<void> update({
    required String id,
    required String title,
    required String description,
    String? instructorId,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    required SeminarStatus status,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink = '',
  }) async {
    await _api.put('/seminars/$id', data: {
      'title': title,
      'description': description,
      if (instructorId != null && instructorId.isNotEmpty) 'instructorId': instructorId,
      'instructorName': instructorName,
      'scheduledStart': scheduledStart.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      'status': status.name,
      'capacity': capacity,
      if (audience != null) 'audience': audience.name,
      'meetingLink': meetingLink,
    });
  }

  @override
  Future<void> delete(String id) async {
    await _api.delete('/seminars/$id');
  }

  @override
  Future<void> setStatus(String id, SeminarStatus status) async {
    await _api.patch('/seminars/$id/status', data: {'status': status.name});
  }
}
