import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/student/guardian_link_store.dart';

/// پارامترهای تولید کد دعوت والد — نام و صنف شاگرد هم لازم است تا پس از
/// لینک‌شدن، والد معلومات درست فرزند را ببیند (نه یک نام hardcode شده).
class GuardianInviteParams {
  final String studentId;
  final String studentName;
  final int grade;
  const GuardianInviteParams({
    required this.studentId,
    required this.studentName,
    required this.grade,
  });
}

abstract class ProfileRepository {
  /// طبق `POST /students/{id}/guardian-invite-code` بخش ۱۹.۲ و ۲.۴ سند
  /// (کد ۶ رقمی، عمر ۷۲ ساعته). کل شیء کد برگردانده می‌شود تا UI بتواند
  /// زمان انقضا را هم نمایش دهد.
  Future<Either<Failure, GuardianInviteCode>> generateGuardianInviteCode(
      GuardianInviteParams params);
}
