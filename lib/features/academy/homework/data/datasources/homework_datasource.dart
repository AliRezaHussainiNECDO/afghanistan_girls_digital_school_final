import '../../domain/entities/homework.dart';

/// قرارداد مشترک DataSource «مشق کاغذی» — Mock و Remote هر دو آن را
/// پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند (طبق الگوی
/// NotificationsDataSource/SeminarsDataSource در بقیهٔ اپ).
abstract class HomeworkDataSource {
  /// فهرست مشق‌های صنف *فعلیِ* شاگرد (سرور خودکار فیلتر می‌کند). اگر
  /// [studentId] پر شود (فقط نمای مدیر روی پروندهٔ یک شاگرد)، سرور به‌جای
  /// فیلتر صنف فعلی، کل تاریخچهٔ همان شاگرد را برمی‌گرداند.
  Future<HomeworkListResult> getHomeworks({HomeworkStatus? status, String? studentId});

  /// جزئیات یک مشق مشخص.
  Future<Homework> getHomeworkById(String id);

  /// تاریخچهٔ گفت‌وگوی «شاگرد ↔ معلم هوشمند» دربارهٔ یک مشق.
  Future<List<HomeworkReply>> getReplies(String homeworkId);

  /// ارسال عکس دست‌خط — بایت‌های خام عکس + نوع فایل. مشق نمره‌دهی‌شده برمی‌گردد
  /// (یا همان مشق با status='submitted' اگر نمره‌دهی هنوز آماده نبود).
  Future<Homework> submitPhoto({
    required String homeworkId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  });

  /// پرسش پیگیری دربارهٔ نمره — کل گفت‌وگوی به‌روزشده برمی‌گردد.
  Future<List<HomeworkReply>> sendReply({required String homeworkId, required String text});
}
