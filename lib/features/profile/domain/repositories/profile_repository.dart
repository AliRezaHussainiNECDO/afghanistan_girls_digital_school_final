import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';

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

/// یک کد دعوت والد (بخش ۲.۴ سند): ۶ رقمی، با عمر ۷۲ ساعت، به‌ازای هر
/// شاگرد فقط یک کد فعال.
///
/// رفع اشکال (۲۴ جولای): این کلاس قبلاً داخل `core/student/guardian_link_store.dart`
/// تعریف شده بود — یعنی حتی `ProfileRemoteDataSource` (پیاده‌سازی *واقعی*ِ
/// متصل به `POST /students/me/guardian-code`) مجبور بود از فایلی که اسمش
/// «Store» (منبع دادهٔ Mock) بود مدل دامنه‌اش را وارد کند. این مدل به لایهٔ
/// دامنهٔ خودِ feature منتقل شد؛ منبع واحد حقیقتِ داده همیشه سرور بوده — این
/// کلاس فقط یک DTO است.
class GuardianInviteCode {
  final String code;
  final String studentId;
  final String studentName;
  final int grade;
  final DateTime issuedAt;
  final DateTime expiresAt;

  const GuardianInviteCode({
    required this.code,
    required this.studentId,
    required this.studentName,
    required this.grade,
    required this.issuedAt,
    required this.expiresAt,
  });

  bool get expired => DateTime.now().isAfter(expiresAt);

  /// ساعت‌های باقی‌مانده تا انقضا (برای نمایش به شاگرد).
  int get remainingHours {
    final d = expiresAt.difference(DateTime.now());
    return d.isNegative ? 0 : d.inHours;
  }
}

abstract class ProfileRepository {
  /// طبق `POST /students/{id}/guardian-invite-code` بخش ۱۹.۲ و ۲.۴ سند
  /// (کد ۶ رقمی، عمر ۷۲ ساعته). کل شیء کد برگردانده می‌شود تا UI بتواند
  /// زمان انقضا را هم نمایش دهد.
  Future<Either<Failure, GuardianInviteCode>> generateGuardianInviteCode(
      GuardianInviteParams params);
}
