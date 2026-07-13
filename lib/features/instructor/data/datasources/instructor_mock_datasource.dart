import '../../../../features/seminars/data/datasources/seminar_store.dart';
import '../../../../shared_models/seminar.dart';
import 'instructor_remote_datasource.dart' show InstructorDataSource;

/// DataSource استاد سمینار — به مخزن مشترک [SeminarStore] وصل است تا
/// سمینارهای ساخته‌شده بلافاصله برای شاگردان/والدین/مدیر هم دیده شوند.
class InstructorMockDataSource implements InstructorDataSource {
  final SeminarStore _store = SeminarStore.instance;

  @override
  Future<List<Seminar>> getMySeminars(String instructorId) =>
      _store.getByInstructor(instructorId);

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
  }) =>
      _store.create(
        title: title,
        description: description,
        instructorId: instructorId,
        instructorName: instructorName,
        scheduledStart: scheduledStart,
        durationMinutes: durationMinutes,
        capacity: capacity,
        audience: audience,
        meetingLink: meetingLink,
      );

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
  }) =>
      _store.update(
        id: id,
        title: title,
        description: description,
        scheduledStart: scheduledStart,
        durationMinutes: durationMinutes,
        capacity: capacity,
        audience: audience,
        meetingLink: meetingLink,
      );

  @override
  Future<void> deleteSeminar(String id) => _store.delete(id);

  @override
  Future<void> setStatus(String id, SeminarStatus status) => _store.setStatus(id, status);
}
