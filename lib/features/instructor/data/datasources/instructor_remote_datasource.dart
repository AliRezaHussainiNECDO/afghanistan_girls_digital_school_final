import '../../../../core/network/api_client.dart';
import '../../../../shared_models/seminar.dart';
import '../../../seminars/data/datasources/seminars_remote_datasource.dart'
    show seminarFromJson;

/// قرارداد مشترک DataSource استاد سمینار — Mock و Remote هر دو آن را
/// پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class InstructorDataSource {
  Future<List<Seminar>> getMySeminars(String instructorId);
  Future<void> createSeminar({
    required String instructorId,
    required String instructorName,
    required String title,
    required String description,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience,
    String meetingLink,
  });
  Future<void> updateSeminar({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink,
  });
  Future<void> deleteSeminar(String id);
  Future<void> setStatus(String id, SeminarStatus status);
}

/// پیاده‌سازی واقعی — روتر seminars زیر `/api/v1` (بخش ۱۹.۸ سند).
class InstructorRemoteDataSource implements InstructorDataSource {
  final ApiClient _api;
  InstructorRemoteDataSource(this._api);

  @override
  Future<List<Seminar>> getMySeminars(String instructorId) async {
    final data = await _api.get('/seminars', queryParameters: {'instructor': instructorId});
    final list = (data['seminars'] as List? ?? []);
    return list.map(seminarFromJson).toList();
  }

  @override
  Future<void> createSeminar({
    required String instructorId,
    required String instructorName,
    required String title,
    required String description,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience = SeminarAudience.students,
    String meetingLink = '',
  }) async {
    await _api.post('/seminars', data: {
      'title': title,
      'description': description,
      'instructorName': instructorName,
      'scheduledStart': scheduledStart.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      if (capacity != null) 'capacity': capacity,
      'audience': audience.name,
      'meetingLink': meetingLink,
    });
  }

  @override
  Future<void> updateSeminar({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink = '',
  }) async {
    await _api.put('/seminars/$id', data: {
      'title': title,
      'description': description,
      'scheduledStart': scheduledStart.toUtc().toIso8601String(),
      'durationMinutes': durationMinutes,
      'capacity': capacity,
      if (audience != null) 'audience': audience.name,
      'meetingLink': meetingLink,
    });
  }

  @override
  Future<void> deleteSeminar(String id) async {
    await _api.delete('/seminars/$id');
  }

  @override
  Future<void> setStatus(String id, SeminarStatus status) async {
    await _api.patch('/seminars/$id/status', data: {'status': status.name});
  }
}
