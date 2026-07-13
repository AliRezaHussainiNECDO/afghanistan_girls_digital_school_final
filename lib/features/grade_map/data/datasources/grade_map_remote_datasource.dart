import '../../../../core/network/api_client.dart';
import '../../domain/entities/grade_map.dart';
import '../models/grade_map_model.dart';

/// قرارداد مشترک DataSource نقشهٔ صنوف — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class GradeMapDataSource {
  Future<GradeMap> getGradeMap(String studentId, {int fallbackGrade});
}

/// پیاده‌سازی واقعی — `GET /api/v1/students/{id}/grade-map` (بخش ۱۹.۲،
/// Server-Authoritative بخش ۶.۷). صنف و وضعیت هر مضمون را Backend محاسبه
/// می‌کند؛ کلاینت فقط نمایش می‌دهد (اصل بخش ۴).
class GradeMapRemoteDataSource implements GradeMapDataSource {
  final ApiClient _api;
  GradeMapRemoteDataSource(this._api);

  @override
  Future<GradeMap> getGradeMap(String studentId, {int fallbackGrade = 7}) async {
    final data = await _api.get('/students/$studentId/grade-map');
    return GradeMapModel.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
