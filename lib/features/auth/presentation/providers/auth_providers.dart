import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
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
  return AuthMockDataSource();
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
    if (user != null && mounted) state = user;
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
    await ref.read(logoutUseCaseProvider).call(const NoParams());
    state = null;
    ref.read(profilePhotoProvider.notifier).state = null;
  }

  /// ویرایش محلی معلومات پروفایل (فاز ۱: بدون بک‌اند واقعی، فقط وضعیت نشست).
  void updateDisplayName(String newName) {
    final current = state;
    if (current == null || newName.trim().isEmpty) return;
    state = current.copyWith(displayName: newName.trim());
  }
}

final authSessionProvider = StateNotifierProvider<AuthSessionNotifier, AppUser?>(
  (ref) => AuthSessionNotifier(ref),
);
