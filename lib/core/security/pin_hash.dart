import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// هشِ نمکی (Salted Hash) سبک برای PIN محلیِ «حالت پنهان».
///
/// این PIN فقط یک قفلِ محلیِ روی خودِ گوشی است (نه رمز عبور حساب سرور)،
/// پس نیازی به الگوریتم سنگین PBKDF2/Argon2 ندارد؛ اما طبق همان اصل «هرگز
/// رمز را متن‌ساده ذخیره نکن» که برای بقیهٔ برنامه هم رعایت شده، این‌جا هم
/// یک salt تصادفی + چند هزار بار تکرار SHA-256 استفاده می‌شود تا حتی با
/// دسترسی مستقیم به فایل SharedPreferences، PIN قابل بازیابی نباشد.
class PinHash {
  PinHash._();

  static const int _iterations = 5000;

  /// یک salt تصادفیِ ۱۶ بایتی (Base64) می‌سازد.
  static String generateSalt() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// هشِ نهایی (Base64) از روی PIN + salt.
  static String hash(String pin, String salt) {
    List<int> digest = utf8.encode('$salt::$pin');
    for (var i = 0; i < _iterations; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }

  /// آیا PIN واردشده با هش ذخیره‌شده مطابقت دارد؟
  static bool verify(String pin, String salt, String expectedHash) {
    return hash(pin, salt) == expectedHash;
  }
}
