import '../../../../core/network/api_client.dart';
import '../../domain/entities/certificate.dart';

/// قرارداد مشترک DataSource گواهی‌نامه — نسخهٔ محلی (فاز ۱) و ریموت (فاز ۲)
/// هر دو آن را پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class CertificatesDataSource {
  Future<List<Certificate>> getAll();
  Future<List<Certificate>> getForStudent(String studentId);
  Future<Certificate> issue({
    required String studentId,
    required String studentName,
    required int grade,
    required String yearLabel,
    required double average,
    required String honor,
  });
  Future<void> revoke(String certificateId);
}

/// پیاده‌سازی واقعی — روتر exams/certificates زیر `/api/v1` (بخش ۸.۲ سند).
class CertificatesRemoteDataSource implements CertificatesDataSource {
  final ApiClient _api;
  CertificatesRemoteDataSource(this._api);

  @override
  Future<List<Certificate>> getForStudent(String studentId) async {
    final data = await _api.get('/students/$studentId/certificates');
    final list = (data['certificates'] as List? ?? []);
    return list.map((e) => Certificate.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// در سرور، «همه» فقط برای مدیر معنا دارد؛ Endpoint اختصاصی نداریم پس از
  /// همان مسیر دانش‌آموزی با شناسهٔ خودِ کاربر استفاده می‌شود (سرور تشخیص
  /// می‌دهد مدیر است یا نه). برای فهرست کامل مدیر، از صفحهٔ مدیریت استفاده شود.
  @override
  Future<List<Certificate>> getAll() async {
    final data = await _api.get('/students/me/certificates');
    final list = (data['certificates'] as List? ?? []);
    return list.map((e) => Certificate.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<Certificate> issue({
    required String studentId,
    required String studentName,
    required int grade,
    required String yearLabel,
    required double average,
    required String honor,
  }) async {
    final data = await _api.post('/admin/certificates', data: {
      'studentId': studentId,
      'studentName': studentName,
      'grade': grade,
      'yearLabel': yearLabel,
      'average': average,
      'honor': honor,
    });
    return Certificate.fromJson(Map<String, dynamic>.from(data['certificate'] as Map));
  }

  @override
  Future<void> revoke(String certificateId) async {
    await _api.delete('/admin/certificates/$certificateId');
  }
}
