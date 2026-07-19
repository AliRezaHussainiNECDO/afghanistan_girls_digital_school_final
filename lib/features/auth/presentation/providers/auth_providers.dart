import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/push/push_notifications_service.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/datasources/auth_mock_datasource.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/repositories_impl/auth_repository_impl.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/usecases/auth_usecases.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// سوییچ Mock ↔ Live Backend.
///
/// • `false` → داده‌های درون‌حافظه‌ای فاز ۱ (بدون سرور؛ حساب‌های Demo کار می‌کنند).
/// • `true`  → Cloudflare Worker واقعی روی
///   `https://api.afghanistangirlsdigitalschool.org/api/v1`.
///
/// می‌توان بدون تغییر کد هم آن را از بیرون تزریق کرد:
///   flutter run --dart-define=USE_LIVE_BACKEND=false   (فقط برای تست UI)
///
/// ⚠️ پیش‌فرض اکنون `true` است: حساب‌ها باید واقعاً در دیتابیس سرور ساخته
/// شوند. حالت Mock فقط درون‌حافظه است و با بسته‌شدن اپ همهٔ حساب‌های
/// ثبت‌نام‌شده از بین می‌روند (همان مشکلی که باعث می‌شد شاگرد بعد از
/// ثبت‌نام دیگر نتواند وارد شود).
/// ═══════════════════════════════════════════════════════════════════════════
const bool kUseLiveBackend = bool.fromEnvironment(
  'USE_LIVE_BACKEND',
  defaultValue: true,
);

/// DataSource احراز هویت — بسته به سوییچ، Mock یا Remote.
/// هر دو `AuthDataSource` را پیاده می‌کنند، پس Repository بدون تغییر می‌ماند.
final authDataSourceProvider = Provider<AuthDataSource>((ref) {
  if (kUseLiveBackend) {
    return AuthRemoteDataSource(
      ref.watch(apiClientProvider),
      ref.watch(tokenStoreProvider),
    );
  }
  return AuthMockDataSource(localeCode: ref.watch(localeProvider).languageCode);
});

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepositoryImpl(ref.watch(authDataSourceProvider)),
);

final loginUseCaseProvider = Provider((ref) => LoginUseCase(ref.watch(authRepositoryProvider)));
final registerStudentUseCaseProvider =
    Provider((ref) => RegisterStudentUseCase(ref.watch(authRepositoryProvider)));
final registerParentUseCaseProvider =
    Provider((ref) => RegisterParentUseCase(ref.watch(authRepositoryProvider)));
final registerInstructorUseCaseProvider =
    Provider((ref) => RegisterInstructorUseCase(ref.watch(authRepositoryProvider)));
final forgotPasswordUseCaseProvider =
    Provider((ref) => ForgotPasswordUseCase(ref.watch(authRepositoryProvider)));
final logoutUseCaseProvider = Provider((ref) => LogoutUseCase(ref.watch(authRepositoryProvider)));

/// وضعیت نشست کاربر (Session) — طبق بخش ۳.۳ سند (مدیریت Token).
/// در فاز ۱ فقط در حافظه نگه‌داشته می‌شود؛ از فاز ۲ به بعد JWT واقعی
/// (Access/Refresh) در `core/network` مدیریت خواهد شد.
class AuthSessionNotifier extends StateNotifier<AppUser?> {
  final Ref ref;
  AuthSessionNotifier(this.ref) : super(null) {
    _restoreSession();
  }

  bool isLoading = false;
  String? lastError;

  /// بازیابی خودکار نشست ذخیره‌شده هنگام باز شدن اپ (بخش ۳.۳ — Refresh
  /// Token). اگر نشست معتبری باشد، Router به‌صورت خودکار کاربر را از صفحهٔ
  /// ورود به داشبورد نقش خودش هدایت می‌کند.
  Future<void> _restoreSession() async {
    final user = await ref.read(authRepositoryProvider).restoreSession();
    if (user != null && mounted) {
      state = user;
      _registerPushDevice();
    }
  }

  /// ثبت توکن دستگاه برای Push Notification واقعی — بعد از هر ورود موفق
  /// (این تابع، و خودِ سرویس، کاملاً Fail-safe‌اند: تا وقتی پروژهٔ Firebase
  /// وصل نشده باشد، بی‌صدا هیچ کاری نمی‌کند و جریان ورود/ثبت‌نام را کند یا
  /// خراب نمی‌کند — به همین دلیل عمداً `await` نمی‌شود).
  void _registerPushDevice() {
    unawaited(ref.read(pushNotificationsServiceProvider).registerCurrentDevice());
  }

  Future<bool> login(String email, String password) async {
    isLoading = true;
    lastError = null;
    state = state; // trigger listeners if needed
    final result = await ref
        .read(loginUseCaseProvider)
        .call(LoginParams(email: email, password: password));
    isLoading = false;
    return result.fold(
      (failure) {
        lastError = failure.message;
        return false;
      },
      (user) {
        state = user;
        _registerPushDevice();
        return true;
      },
    );
  }

  Future<bool> registerStudent(RegisterStudentParams params) async {
    isLoading = true;
    lastError = null;
    final result = await ref.read(registerStudentUseCaseProvider).call(params);
    isLoading = false;
    return result.fold((failure) {
      lastError = failure.message;
      return false;
    }, (user) {
      state = user;
      _registerPushDevice();
      return true;
    });
  }

  Future<bool> registerParent(RegisterParentParams params) async {
    isLoading = true;
    lastError = null;
    final result = await ref.read(registerParentUseCaseProvider).call(params);
    isLoading = false;
    return result.fold((failure) {
      lastError = failure.message;
      return false;
    }, (user) {
      state = user;
      _registerPushDevice();
      return true;
    });
  }

  /// ثبت‌نام استاد سمینار با کد دعوت مدیر — موفقیت = ورود مستقیم به پنل استاد.
  Future<bool> registerInstructor(RegisterInstructorParams params) async {
    isLoading = true;
    lastError = null;
    final result = await ref.read(registerInstructorUseCaseProvider).call(params);
    isLoading = false;
    return result.fold((failure) {
      lastError = failure.message;
      return false;
    }, (user) {
      state = user;
      _registerPushDevice();
      return true;
    });
  }

  Future<bool> forgotPassword(String email) async {
    isLoading = true;
    final result = await ref.read(forgotPasswordUseCaseProvider).call(email);
    isLoading = false;
    return result.isRight();
  }

  /// تغییر رمز با کد ۶ رقمی ایمیل‌شده (بخش ۳.۴).
  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    isLoading = true;
    lastError = null;
    final result = await ref
        .read(authRepositoryProvider)
        .resetPassword(email: email, code: code, newPassword: newPassword);
    isLoading = false;
    return result.fold((failure) {
      lastError = failure.message;
      return false;
    }, (_) => true);
  }

  /// ارسال مجدد لینک تأیید ایمیل برای کاربر فعلی (یا ایمیل داده‌شده).
  Future<void> resendVerification([String? email]) async {
    final target = email ?? state?.email;
    if (target == null || target.isEmpty) return;
    await ref.read(authRepositoryProvider).resendVerification(target);
  }

  /// آپلود عکس پروفایل روی سرور و به‌روزرسانی نشست. خروجی: آدرس عکس یا null.
  Future<String?> uploadAvatar(List<int> bytes, String contentType) async {
    final result =
        await ref.read(authRepositoryProvider).uploadAvatar(bytes, contentType);
    return result.fold((failure) {
      lastError = failure.message;
      return null;
    }, (url) {
      final current = state;
      if (url != null && current != null) {
        state = current.copyWith(avatarUrl: url);
      }
      return url;
    });
  }

  Future<void> logout() async {
    // قبل از پاک‌کردن نشست: این دستگاه دیگر نباید برای این کاربر Push بگیرد
    // (مثلاً روی گوشی مشترک بین چند شاگرد). Fail-safe — اگر Firebase وصل
    // نباشد یا شبکه قطع باشد، خروج از حساب هرگز به همین دلیل معطل نمی‌ماند.
    await ref.read(pushNotificationsServiceProvider).unregisterCurrentDevice().timeout(
          const Duration(seconds: 3),
          onTimeout: () {},
        );
    await ref.read(logoutUseCaseProvider).call(const NoParams());
    state = null;
    ref.read(profilePhotoProvider.notifier).state = null;
  }

  /// تغییر رمز عبور — رفع اشکال: قبلاً دیالوگ «تغییر رمز» در UI هیچ
  /// درخواستی به سرور نمی‌فرستاد و صرفاً پیام موفقیت ساختگی نشان می‌داد.
  /// چون سرور پس از تغییر موفق همهٔ نشست‌ها (این دستگاه هم) را باطل می‌کند،
  /// در صورت موفقیت بلافاصله `logout()` محلی هم انجام می‌شود تا کاربر با
  /// رمز تازه دوباره وارد شود.
  Future<bool> changePassword({required String currentPassword, required String newPassword}) async {
    final result = await ref
        .read(authRepositoryProvider)
        .changePassword(currentPassword: currentPassword, newPassword: newPassword);
    return result.fold((failure) {
      lastError = failure.message;
      return false;
    }, (_) {
      logout();
      return true;
    });
  }

  /// ویرایش نام کاربر فعلی — رفع اشکال: قبلاً فقط `state` محلی نشست تغییر
  /// می‌کرد و هرگز روی سرور ذخیره نمی‌شد، پس با ورود مجدد یا در سایر
  /// داشبوردها (فهرست شاگردان مدیر، هم‌صنفی‌های چت، ثبت‌نامی سمینار و...) نام
  /// قدیمی همچنان دیده می‌شد. اکنون واقعاً `PATCH /auth/me` را صدا می‌زند.
  /// نام کامل روی اولین فاصله به نام/تخلص تقسیم می‌شود (هماهنگ با ساختار
  /// `first_name`/`last_name` جدول `users`).
  Future<bool> updateDisplayName(String newName) async {
    final current = state;
    final trimmed = newName.trim();
    if (current == null || trimmed.isEmpty) return false;
    final parts = trimmed.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    return updateProfileName(firstName: firstName, lastName: lastName);
  }

  /// ویرایش دقیق نام/تخلص — بدون گِرد شدنِ رفت‌وبرگشتی «یک رشته → تقسیم روی
  /// اولین فاصله»؛ مستقیماً همان دو فیلدِ جدول `users` (`first_name`/
  /// `last_name`) را روی سرور به‌روزرسانی می‌کند. صفحهٔ ویرایش پروفایل
  /// (بخش پروفایل هر داشبورد) اکنون این دو فیلد را جداگانه می‌گیرد تا
  /// تخلص‌های چندبخشی هم درست ذخیره شوند.
  Future<bool> updateProfileName({required String firstName, required String lastName}) async {
    final current = state;
    if (current == null) return false;
    final result = await ref
        .read(authRepositoryProvider)
        .updateProfile(firstName: firstName.trim(), lastName: lastName.trim());
    return result.fold((failure) {
      lastError = failure.message;
      return false;
    }, (updated) {
      state = updated;
      return true;
    });
  }

  /// پس از ارتقای واقعی صنف روی سرور (پیروزی در امتحان نهایی یا اقدام
  /// مدیر)، صنف فعال نشست را بلافاصله به‌روز می‌کند — بدون نیاز به ورود
  /// مجدد — تا «نصاب درسی» و بقیهٔ صفحه‌ها فوراً صنف تازه را نشان دهند.
  void updateCurrentGrade(int newGrade) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(currentGrade: newGrade);
  }
}

final authSessionProvider = StateNotifierProvider<AuthSessionNotifier, AppUser?>(
  (ref) => AuthSessionNotifier(ref),
);
