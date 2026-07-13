import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/parent_entities.dart';

/// پارامترهای واردکردن کد دعوت توسط والد — هر پیوند متعلق به یک والدِ
/// مشخص است (`parent_student_links.parent_id`).
class SubmitInviteParams {
  final String parentId;

  /// نام والد — روی درخواست پیوند ثبت می‌شود تا شاگرد هنگام تأیید بداند
  /// چه کسی درخواست داده (اصلاح ۲.۴).
  final String parentName;
  final String code;
  const SubmitInviteParams({required this.parentId, this.parentName = '', required this.code});
}

abstract class ParentRepository {
  /// فرزندان تأییدشدهٔ همین والد (بخش ۱۳ب.۵ — چند فرزند، یک والد).
  Future<Either<Failure, List<LinkedChild>>> getLinkedChildren(String parentId);

  Future<Either<Failure, ChildSummary>> getChildSummary(String studentId);

  /// طبق بخش ۱۳ب.۲ (اصلاح ۲.۴): والد کد دعوت فرزند را وارد می‌کند →
  /// درخواست پیوند با وضعیت «در انتظار تأیید شاگرد» ثبت می‌شود و پس از
  /// تأیید فرزند فعال می‌گردد. خروجی موفق = نام فرزند (برای پیام تأیید).
  Future<Either<Failure, String>> submitInviteCode(SubmitInviteParams params);
}
