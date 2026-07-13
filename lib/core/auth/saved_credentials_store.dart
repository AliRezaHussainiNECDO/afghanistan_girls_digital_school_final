import 'package:shared_preferences/shared_preferences.dart';

/// نگهداری ایمیل/پسورد ورود برای گزینهٔ «مرا به خاطر بسپار» در صفحهٔ لاگین.
///
/// نکتهٔ امنیتی: ذخیره فقط با انتخاب صریح کاربر انجام می‌شود و با خاموش‌کردن
/// گزینه (یا ورود بدون آن) بلافاصله پاک می‌شود. در فاز امنیتی بعدی می‌توان
/// بدون تغییر امضای این کلاس، پشتوانه را به `flutter_secure_storage`
/// (Keystore/Keychain) ارتقا داد.
class SavedCredentialsStore {
  static const _kRemember = 'login_remember_me';
  static const _kEmail = 'login_saved_email';
  static const _kPassword = 'login_saved_password';

  /// خواندن اطلاعات ذخیره‌شده؛ اگر گزینه فعال نباشد null برمی‌گردد.
  static Future<({String email, String password})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kRemember) != true) return null;
    final email = prefs.getString(_kEmail) ?? '';
    final password = prefs.getString(_kPassword) ?? '';
    if (email.isEmpty) return null;
    return (email: email, password: password);
  }

  /// ذخیرهٔ اطلاعات پس از ورود موفق با گزینهٔ فعال.
  static Future<void> save(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kRemember, true);
    await prefs.setString(_kEmail, email);
    await prefs.setString(_kPassword, password);
  }

  /// پاک‌کردن کامل (گزینه خاموش شد یا کاربر نخواست).
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRemember);
    await prefs.remove(_kEmail);
    await prefs.remove(_kPassword);
  }
}
