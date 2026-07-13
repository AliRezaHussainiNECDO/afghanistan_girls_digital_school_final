import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefsKey = 'preferred_language';

/// مدیریت زبان فعال اپ — طبق فیلد `users.preferred_language`
/// (ENUM('fa','ps','en') — بخش ۱۷.۱ سند). در فاز ۱ فقط محلی ذخیره می‌شود؛
/// از فاز ۲ به بعد با پروفایل واقعی کاربر همگام خواهد شد.
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('fa')) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_localePrefsKey);
    if (saved != null) {
      state = Locale(saved);
    }
  }

  Future<void> setLocale(Locale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localePrefsKey, locale.languageCode);
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());
