import 'package:dartz/dartz.dart';

import '../../../../../core/errors/failures.dart';
import '../entities/homework.dart';

abstract class HomeworkRepository {
  /// فهرست مشق‌های صنف فعلی شاگرد؛ [status] برای فیلتر تب‌های «همه/در
  /// انتظار/ارسال‌شده/نمره‌گرفته». [studentId] فقط برای نمای مدیر روی پروندهٔ
  /// یک شاگرد مشخص پر می‌شود (سرور در این حالت کل تاریخچه را برمی‌گرداند، نه
  /// فقط صنف فعلی — بخش `GET /homework?studentId=` در routes/homework.ts).
  Future<Either<Failure, HomeworkListResult>> getHomeworks({HomeworkStatus? status, String? studentId});

  /// جزئیات یک مشق مشخص.
  Future<Either<Failure, Homework>> getHomeworkById(String id);

  /// تاریخچهٔ گفت‌وگوی «شاگرد ↔ معلم هوشمند» دربارهٔ یک مشق.
  Future<Either<Failure, List<HomeworkReply>>> getReplies(String homeworkId);

  /// ارسال عکس دست‌خط شاگرد — نمره‌دهی خودکار (Vision) و برگشت مشق به‌روزشده.
  Future<Either<Failure, Homework>> submitPhoto({
    required String homeworkId,
    required List<int> bytes,
    required String fileName,
    required String contentType,
  });

  /// پرسش پیگیری دربارهٔ نمره/بازخورد — کل گفت‌وگوی به‌روزشده برمی‌گردد.
  Future<Either<Failure, List<HomeworkReply>>> sendReply({
    required String homeworkId,
    required String text,
  });
}
