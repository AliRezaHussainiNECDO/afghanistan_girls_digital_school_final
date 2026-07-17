import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/app_user.dart';

/// Interface انتزاعی احراز هویت — طبق بخش ۲۴.۱/۲۴.۳ سند.
/// پیاده‌سازی واقعی (data/repositories_impl) در فاز ۱ از Mock DataSource
/// و از فاز ۲ به بعد از Remote DataSource واقعی (بخش ۱۹.۱) استفاده می‌کند.
abstract class AuthRepository {
  Future<Either<Failure, AppUser>> login({
    required String email,
    required String password,
  });

  Future<Either<Failure, AppUser>> registerStudent({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String email,
    required String phone,
    required String password,
    required int currentGrade,
    required String province,
    required String inviteCode, // اجباری — بخش ۳ب.۲
  });

  Future<Either<Failure, AppUser>> registerParent({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  });

  /// ثبت‌نام استاد سمینار — فقط با کد دعوتی که مدیر ساخته است (بخش ۲.۲:
  /// «افزودن استاد» در انحصار Super Admin). کد یک‌بارمصرف است و حساب را
  /// بلافاصله فعال می‌کند.
  Future<Either<Failure, AppUser>> registerInstructor({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String specialty,
    required String bio,
    required String inviteCode,
  });

  Future<Either<Failure, Unit>> forgotPassword(String email);

  /// تغییر رمز با کد ۶ رقمی دریافتی در ایمیل (بخش ۳.۴).
  Future<Either<Failure, Unit>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// ارسال مجدد لینک تأیید ایمیل.
  Future<Either<Failure, Unit>> resendVerification(String email);

  /// بازیابی نشست ذخیره‌شده (Refresh Token) هنگام باز شدن اپ.
  Future<AppUser?> restoreSession();

  /// آپلود عکس پروفایل؛ خروجی آدرس کامل عکس روی سرور یا null.
  Future<Either<Failure, String?>> uploadAvatar(List<int> bytes, String contentType);

  /// ویرایش نام کاربر فعلی روی سرور (رفع اشکال: قبلاً فقط `state` محلی نشست
  /// تغییر می‌کرد و با ورود مجدد یا در سایر داشبوردها دیده نمی‌شد).
  Future<Either<Failure, AppUser>> updateProfile({
    required String firstName,
    required String lastName,
  });

  /// تغییر رمز عبور کاربر واردشده (نیاز به رمز فعلی) — رفع اشکال: قبلاً این
  /// دیالوگ در UI هیچ درخواستی به سرور نمی‌فرستاد و صرفاً پیام موفقیت
  /// ساختگی نشان می‌داد.
  Future<Either<Failure, Unit>> changePassword({
    required String currentPassword,
    required String newPassword,
  });

  Future<Either<Failure, Unit>> logout();

  Future<AppUser?> getCurrentUser();
}
