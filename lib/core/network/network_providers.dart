import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/locale_provider.dart';
import 'api_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Providerهای لایهٔ شبکه (بخش ۲۴.۷ سند — Dependency Injection).
/// اینجا `ApiClient` و انبار Token به‌صورت Singleton برنامه ساخته و به بقیهٔ
/// اپ تزریق می‌شوند.
/// ═══════════════════════════════════════════════════════════════════════════

/// انبار Token احراز هویت (JWT — بخش ۳.۳ سند).
///
/// نسخهٔ درون‌حافظه + پایدار روی `shared_preferences`؛ getter همگام
/// (`accessToken`) برای Interceptor استفاده می‌شود، و ذخیره/بارگذاری async.
/// در فاز امنیتی بعد می‌توان به `flutter_secure_storage` ارتقا داد بدون
/// تغییر در امضای عمومی.
class TokenStore {
  static const _kAccess = 'auth_access_token';
  static const _kRefresh = 'auth_refresh_token';

  String? _access;
  String? _refresh;

  String? get accessToken => _access;
  String? get refreshToken => _refresh;
  bool get isLoggedIn => _access != null && _access!.isNotEmpty;

  /// بارگذاری Tokenهای ذخیره‌شده هنگام راه‌اندازی اپ (در `main()` صدا بزنید).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString(_kAccess);
    _refresh = prefs.getString(_kRefresh);
  }

  Future<void> saveTokens({String? access, String? refresh}) async {
    _access = access;
    _refresh = refresh;
    final prefs = await SharedPreferences.getInstance();
    if (access == null || access.isEmpty) {
      await prefs.remove(_kAccess);
    } else {
      await prefs.setString(_kAccess, access);
    }
    if (refresh == null || refresh.isEmpty) {
      await prefs.remove(_kRefresh);
    } else {
      await prefs.setString(_kRefresh, refresh);
    }
  }

  Future<void> clear() => saveTokens(access: null, refresh: null);
}

/// انبار Token — یک نمونه برای کل اپ.
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

/// هدرِ Authorization برای درخواست‌های تصویر/فایلِ مستقیم (`Image.network`
/// و مشابه) که از میان‌کارِ خودکارِ `ApiClient` عبور نمی‌کنند.
///
/// رفعِ اشکالِ امنیتی: `GET /files/*` سمت سرور دیگر برای همهٔ کلیدها بدونِ
/// ورود پاسخ نمی‌دهد (نگاه کنید backend/src/routes/media.ts — بخصوص
/// `homework/…` و `voice/…`)، پس هرجا مستقیماً (نه از طریق `ApiClient`) به
/// چنین آدرسی وصل می‌شویم باید همین هدر را هم بفرستیم، وگرنه با ۴۰۱ مواجه
/// می‌شویم. از هر `BuildContext` قابلِ‌فراخوانی است (حتی در ویجت‌های
/// Stateless/غیر-Consumer) چون از `ProviderScope.containerOf` استفاده می‌کند.
Map<String, String> authImageHeaders(BuildContext context) {
  final token = ProviderScope.containerOf(context).read(tokenStoreProvider).accessToken;
  return (token == null || token.isEmpty) ? const {} : {'Authorization': 'Bearer $token'};
}

/// کلاینت API پیکربندی‌شده. Token را از `TokenStore` می‌خواند و روی 401
/// به‌صورت خودکار Tokenها را پاک می‌کند (Logout سبک).
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  return ApiClient(
    tokenProvider: () => tokens.accessToken,
    // رفع اشکال «قطع نشست بعد از چند دقیقه»: قبلاً Refresh Token فقط یک‌بار
    // هنگام باز کردن اپ استفاده می‌شد؛ حالا ApiClient خودش هر ۴۰۱ میان‌کاری
    // را با همین Refresh Token تمدید می‌کند — بدون این دو Callback، آن تمدید
    // خاموش اصلاً امکان‌پذیر نیست.
    refreshTokenProvider: () => tokens.refreshToken,
    onTokensRefreshed: (access, refresh) {
      // به‌روزرسانیِ درون‌حافظه‌ای بلافاصله (همگام) اتفاق می‌افتد؛ نوشتن
      // روی دیسک به‌صورت ناهمگام در پس‌زمینه ادامه می‌یابد — تا هیچ تأخیری
      // در تکمیل درخواستِ در حال تلاش‌مجدد ایجاد نشود.
      tokens.saveTokens(access: access, refresh: refresh ?? tokens.refreshToken);
    },
    onUnauthorized: () {
      // پاک‌سازی Token منقضی/نامعتبر؛ هدایت به صفحهٔ ورود در لایهٔ UI
      // (Router) بر اساس خالی‌شدن نشست انجام می‌شود.
      tokens.clear();
    },
    // فقط در Build توسعه (Debug) لاگ شود؛ در Release اطلاعات حساس (توکن/رمز)
    // در کنسول چاپ نمی‌شود.
    enableLogging: kDebugMode,
    localeCode: ref.watch(localeProvider).languageCode,
  );
});
