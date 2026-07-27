import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// پل ارتباطی با کدِ بومی اندروید (MainActivity.kt) برای «حالت پنهان»:
/// ۱) سوییچِ آیکونِ launcher بین برند واقعی و نمایهٔ «ماشین‌حساب».
/// ۲) شنیدنِ رویدادِ نگه‌داشتنِ ۳-ثانیه‌ایِ دکمهٔ صدا-کم (فقط وقتی اپ در
///    پیش‌زمینه است — محدودیتِ ذاتیِ اندروید برای اپ‌های معمولی).
///
/// در iOS/وب این قابلیت اصلاً وجود ندارد (اپل اجازهٔ تغییر بی‌صدای
/// آیکون/نام را نمی‌دهد و دکمهٔ صدا هم در اختیار اپ‌های عادی نیست)؛ تمام
/// متدها روی پلتفرم‌های غیر-اندروید بی‌خطر no-op هستند.
class HiddenModeNativeBridge {
  HiddenModeNativeBridge._();
  static final instance = HiddenModeNativeBridge._();

  static const _methodChannel = MethodChannel('agds/hidden_mode');
  static const _volumeEventChannel = EventChannel('agds/hidden_mode/volume');

  bool get isSupportedPlatform => !kIsWeb && Platform.isAndroid;

  Future<void> setDisguised(bool disguised) async {
    if (!isSupportedPlatform) return;
    try {
      await _methodChannel.invokeMethod<bool>('setDisguised', {'disguised': disguised});
    } catch (_) {
      // Fail-safe: اگر کدِ بومی در دسترس نبود (مثلاً نسخهٔ قدیمی‌تر build)،
      // حالت داخلیِ Flutter (صفحهٔ ماشین‌حساب) همچنان کار می‌کند؛ فقط
      // آیکونِ launcher عوض نمی‌شود.
    }
  }

  Future<bool> isDisguised() async {
    if (!isSupportedPlatform) return false;
    try {
      final result = await _methodChannel.invokeMethod<bool>('isDisguised');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// جریانِ رویدادِ «hide» — هر بار که دکمهٔ صدا-کم ۳ ثانیه نگه داشته شود.
  Stream<String> get volumeHideEvents {
    if (!isSupportedPlatform) return const Stream.empty();
    return _volumeEventChannel.receiveBroadcastStream().map((e) => e as String);
  }
}
