import '../../../../shared_models/seminar.dart';
import 'seminar_store.dart';
import 'seminars_remote_datasource.dart' show SeminarsDataSource;

/// DataSource سمینارها برای شاگرد/والد — به مخزن مشترک [SeminarStore]
/// وصل است تا همهٔ نقش‌ها دادهٔ یکسان ببینند.
class SeminarsMockDataSource implements SeminarsDataSource {
  final SeminarStore _store = SeminarStore.instance;

  /// سمینارهای قابل مشاهده بر اساس مخاطب (شاگردان یا والدین).
  @override
  Future<List<Seminar>> getUpcoming(SeminarAudience audience) =>
      _store.getVisibleFor(audience);

  @override
  Future<Seminar> getById(String id) => _store.getById(id);

  /// ثبت‌نام فقط یک‌بار — خطاها به‌صورت [Failure] از Store بالا می‌آیند.
  @override
  Future<void> register(String seminarId, String userId) =>
      _store.register(seminarId, userId);

  @override
  Future<void> unregister(String seminarId, String userId) =>
      _store.unregister(seminarId, userId);

  @override
  Future<void> setStatus(String seminarId, SeminarStatus status) =>
      _store.setStatus(seminarId, status);
}
