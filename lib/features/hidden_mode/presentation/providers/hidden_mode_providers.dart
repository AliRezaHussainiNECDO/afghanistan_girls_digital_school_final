import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/security/pin_hash.dart';
import '../../data/hidden_mode_native_bridge.dart';

const _kEnabledKey = 'hidden_mode_enabled_v1';
const _kHashKey = 'hidden_mode_pin_hash_v1';
const _kSaltKey = 'hidden_mode_pin_salt_v1';
const _kHiddenKey = 'hidden_mode_is_hidden_v1';

/// وضعیتِ «حالت پنهان»:
/// • [loading] — هنوز از حافظهٔ محلی خوانده نشده (لحظهٔ خیلی کوتاهِ استارت).
/// • [enabled] — آیا کاربر یک‌بار این قابلیت را با یک PIN راه‌اندازی کرده.
/// • [isHidden] — آیا همین الان اپ باید به‌جای محتوای واقعی، صفحهٔ
///   ماشین‌حسابِ نمایشی را نشان دهد. این پرچم روی حافظهٔ محلی هم ذخیره
///   می‌شود (طبق طراحی توافق‌شده: اگر فعال باشد، حتی پس از بستن کامل و باز
///   کردن دوبارهٔ برنامه هم اول ماشین‌حساب دیده می‌شود، تا وقتی PIN درست
///   وارد شود).
class HiddenModeState {
  final bool loading;
  final bool enabled;
  final bool isHidden;

  const HiddenModeState({this.loading = true, this.enabled = false, this.isHidden = false});

  HiddenModeState copyWith({bool? loading, bool? enabled, bool? isHidden}) => HiddenModeState(
        loading: loading ?? this.loading,
        enabled: enabled ?? this.enabled,
        isHidden: isHidden ?? this.isHidden,
      );
}

class HiddenModeNotifier extends StateNotifier<HiddenModeState> {
  HiddenModeNotifier() : super(const HiddenModeState()) {
    unawaited(_load());
    _listenVolumeGesture();
  }

  final _bridge = HiddenModeNativeBridge.instance;
  StreamSubscription<String>? _volumeSub;
  String? _pinHash;
  String? _pinSalt;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _pinHash = prefs.getString(_kHashKey);
    _pinSalt = prefs.getString(_kSaltKey);
    final enabled = prefs.getBool(_kEnabledKey) ?? false;
    final hidden = enabled && (prefs.getBool(_kHiddenKey) ?? false);
    state = state.copyWith(loading: false, enabled: enabled, isHidden: hidden);
    // هماهنگ‌سازی آیکونِ بومیِ launcher با آخرین وضعیتِ ذخیره‌شده (مثلاً بعد
    // از آپدیت نسخهٔ اپ از Play Store که کدِ بومی را دوباره نصب می‌کند).
    await _bridge.setDisguised(hidden);
  }

  void _listenVolumeGesture() {
    _volumeSub = _bridge.volumeHideEvents.listen((_) {
      if (state.enabled && !state.isHidden) {
        hide();
      }
    });
  }

  /// راه‌اندازیِ اولیه: تنظیم PIN و روشن‌کردنِ قابلیت. خودِ اپ را بلافاصله
  /// پنهان نمی‌کند — فقط اهرم را فعال می‌کند؛ پنهان‌شدنِ واقعی فقط با نگه‌
  /// داشتنِ ۳-ثانیه‌ایِ دکمهٔ صدا-کم اتفاق می‌افتد.
  Future<void> setup(String pin) async {
    final salt = PinHash.generateSalt();
    final hash = PinHash.hash(pin, salt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, true);
    await prefs.setString(_kHashKey, hash);
    await prefs.setString(_kSaltKey, salt);
    await prefs.setBool(_kHiddenKey, false);
    _pinHash = hash;
    _pinSalt = salt;
    state = state.copyWith(enabled: true, isHidden: false);
    await _bridge.setDisguised(false);
  }

  Future<void> hide() async {
    if (!state.enabled) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHiddenKey, true);
    state = state.copyWith(isHidden: true);
    await _bridge.setDisguised(true);
  }

  /// PIN درست بود؟ اگر بله، اپ به حالتِ عادی و نمایان بازمی‌گردد.
  Future<bool> reveal(String pin) async {
    if (_pinHash == null || _pinSalt == null) return false;
    final ok = PinHash.verify(pin, _pinSalt!, _pinHash!);
    if (!ok) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHiddenKey, false);
    state = state.copyWith(isHidden: false);
    await _bridge.setDisguised(false);
    return true;
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (_pinHash == null || _pinSalt == null) return false;
    if (!PinHash.verify(oldPin, _pinSalt!, _pinHash!)) return false;
    final salt = PinHash.generateSalt();
    final hash = PinHash.hash(newPin, salt);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kHashKey, hash);
    await prefs.setString(_kSaltKey, salt);
    _pinHash = hash;
    _pinSalt = salt;
    return true;
  }

  /// خاموش‌کردنِ کامل قابلیت — فقط از داخلِ برنامهٔ نمایان (بعد از تأیید
  /// PIN فعلی) صدا زده می‌شود، هرگز از صفحهٔ ماشین‌حساب.
  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabledKey, false);
    await prefs.remove(_kHashKey);
    await prefs.remove(_kSaltKey);
    await prefs.setBool(_kHiddenKey, false);
    _pinHash = null;
    _pinSalt = null;
    state = state.copyWith(enabled: false, isHidden: false);
    await _bridge.setDisguised(false);
  }

  /// لایهٔ دفاعیِ دوم: وقتی اپ به پس‌زمینه می‌رود (صفحه قفل می‌شود یا کاربر
  /// اپ دیگری باز می‌کند)، اگر قابلیت فعال است، خودکار دوباره پنهان شود —
  /// حتی اگر کاربر فرصت نگه‌داشتنِ دکمهٔ صدا را نداشته باشد.
  void reHideOnBackground() {
    if (state.enabled && !state.isHidden) {
      hide();
    }
  }

  @override
  void dispose() {
    _volumeSub?.cancel();
    super.dispose();
  }
}

final hiddenModeProvider =
    StateNotifierProvider<HiddenModeNotifier, HiddenModeState>((ref) => HiddenModeNotifier());
