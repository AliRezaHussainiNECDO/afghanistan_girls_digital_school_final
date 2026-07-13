import '../../../../../features/seminars/data/datasources/seminar_store.dart';
import '../../../../../shared_models/seminar.dart';
import 'admin_seminars_remote_datasource.dart' show AdminSeminarsDataSource;

/// DataSource مدیریت سمینارها (Super Admin) — به مخزن مشترک [SeminarStore]
/// وصل است: مدیر همهٔ سمینارها (همهٔ استادان، همهٔ وضعیت‌ها) را می‌بیند.
class AdminSeminarsMockDataSource implements AdminSeminarsDataSource {
  final SeminarStore _store = SeminarStore.instance;

  @override
  Future<List<Seminar>> getAll() => _store.getAll();

  @override
  Future<void> create({
    required String title,
    required String description,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience = SeminarAudience.students,
    String meetingLink = '',
  }) =>
      _store.create(
        title: title,
        description: description,
        instructorId: 'u-admin-demo',
        instructorName: instructorName,
        scheduledStart: scheduledStart,
        durationMinutes: durationMinutes,
        capacity: capacity,
        audience: audience,
        meetingLink: meetingLink,
      );

  @override
  Future<void> update({
    required String id,
    required String title,
    required String description,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    required SeminarStatus status,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink = '',
  }) =>
      _store.update(
        id: id,
        title: title,
        description: description,
        instructorName: instructorName,
        scheduledStart: scheduledStart,
        durationMinutes: durationMinutes,
        status: status,
        capacity: capacity,
        audience: audience,
        meetingLink: meetingLink,
      );

  @override
  Future<void> delete(String id) => _store.delete(id);

  @override
  Future<void> setStatus(String id, SeminarStatus status) => _store.setStatus(id, status);
}
