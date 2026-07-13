import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

/// کلاینت API پیکربندی‌شده. Token را از `TokenStore` می‌خواند و روی 401
/// به‌صورت خودکار Tokenها را پاک می‌کند (Logout سبک).
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  return ApiClient(
    tokenProvider: () => tokens.accessToken,
    onUnauthorized: () {
      // پاک‌سازی Token منقضی/نامعتبر؛ هدایت به صفحهٔ ورود در لایهٔ UI
      // (Router) بر اساس خالی‌شدن نشست انجام می‌شود.
      tokens.clear();
    },
    // در Build تولیدی لاگ را خاموش کنید تا اطلاعات حساس در کنسول چاپ نشود.
    enableLogging: true,
  );
});
