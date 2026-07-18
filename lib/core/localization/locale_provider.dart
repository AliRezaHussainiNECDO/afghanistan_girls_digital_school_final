import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefsKey = 'preferred_language';

/// مدیریت زبان فعال اپ — چهار زبان پشتیبانی‌شده: fa (دری) | ps (پښتو) |
/// en (English) | fr (Français). همیشه محلی (SharedPreferences) ذخیره
/// می‌شود؛ صفحهٔ انتخاب زبان اولین‌بار (`LanguageSelectScreen`) و هر
/// دکمهٔ تغییر زبان در برنامه (منوی کناری، پروفایل) از همین Provider واحد
/// استفاده می‌کنند تا با یک انتخاب، *کل* برنامه بلافاصله زبان عوض کند.
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
