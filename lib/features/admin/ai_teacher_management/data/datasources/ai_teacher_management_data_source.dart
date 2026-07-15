import '../../domain/entities/ai_teacher_config.dart';

/// قرارداد مشترک DataSource «مدیریت معلم هوشمند» — نسخهٔ محلی (فاز ۱،
/// SharedPreferences) و ریموت (فاز ۲، سرور واقعی) هر دو آن را پیاده می‌کنند
/// تا با سوییچ `kUseLiveBackend` تعویض شوند (همان الگوی بقیهٔ ماژول‌ها).
abstract class AiTeacherManagementDataSource {
  Future<List<AiTeacherConfig>> getConfigs();
  Future<String?> personaFor(String subjectId);
  Future<void> updatePersona(String subjectId, String newDescription);
}
