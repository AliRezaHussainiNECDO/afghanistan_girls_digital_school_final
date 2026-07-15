import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/ai_teacher_config.dart';
import '../entities/ai_teacher_stats.dart';

abstract class AiTeacherManagementRepository {
  Future<Either<Failure, List<AiTeacherConfig>>> getConfigs();
  Future<Either<Failure, Unit>> updatePersona(String subjectId, String newDescription);

  /// شخصیت تنظیم‌شدهٔ مدیر برای یک مضمون — مصرف‌شونده توسط موتور واقعی
  /// معلم هوشمند تا آنچه مدیر در «مدیریت معلم هوشمند» ذخیره می‌کند واقعاً
  /// روی تجربهٔ شاگرد اثر بگذارد.
  Future<Either<Failure, String?>> getPersonaFor(String subjectId);

  /// آمار حقیقی استفاده از معلم هوشمند برای کارت‌های بالای پنل مدیر.
  Future<Either<Failure, AiTeacherStats>> getStats();
}
