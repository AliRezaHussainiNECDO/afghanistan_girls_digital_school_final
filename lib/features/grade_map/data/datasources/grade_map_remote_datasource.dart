import '../../../../core/network/api_client.dart';
import '../../domain/entities/grade_map.dart';
import '../models/grade_map_model.dart';

/// قرارداد مشترک DataSource نقشهٔ صنوف — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class GradeMapDataSource {
  /// [grade]: کدام صنف واکشی شود — طبق «نوار انتخاب صنف» (صنف فعال یا یکی
  /// از صنوف پایین‌ترِ تکمیل‌شده برای مرور). رفع اشکال: قبلاً این پارامتر
  /// وجود نداشت و همیشه فقط صنف فعال برمی‌گشت، صرف‌نظر از صنفِ انتخاب‌شده.
  Future<GradeMap> getGradeMap(String studentId, {required int grade, int fallbackGrade});
}

/// پیاده‌سازی واقعی — `GET /api/v1/students/{id}/grade-map?grade=` (بخش
/// ۱۹.۲، Server-Authoritative بخش ۶.۷). صنف و وضعیت هر مضمون را Backend
/// محاسبه می‌کند؛ کلاینت فقط نمایش می‌دهد (اصل بخش ۴).
class GradeMapRemoteDataSource implements GradeMapDataSource {
  final ApiClient _api;
  GradeMapRemoteDataSource(this._api);

  @override
  Future<GradeMap> getGradeMap(String studentId, {required int grade, int fallbackGrade = 7}) async {
    final data = await _api.get('/students/$studentId/grade-map', queryParameters: {'grade': grade});
    return GradeMapModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
