import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _languageChosenKey = 'language_chosen_v1';

/// آیا کاربر زبان برنامه را (اولین بار پس از نصب) به‌صورت صریح انتخاب کرده
/// است؟ طبق درخواست کاربر: پیش از هر صفحهٔ دیگر — حتی پیش از صفحهٔ
/// خوش‌آمدید — باید یک‌بار از کاربر زبان (دری/پښتو/English/Français)
/// پرسیده شود؛ این پرچم دقیقاً همان لحظه را نشان می‌دهد.
/// null = هنوز از حافظه خوانده نشده، false = هنوز انتخاب نکرده، true = انتخاب کرده.
class LanguageChosenNotifier extends StateNotifier<bool?> {
  LanguageChosenNotifier() : super(null) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_languageChosenKey) ?? false;
  }

  Future<void> markChosen() async {
    state = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_languageChosenKey, true);
  }
}

final languageChosenProvider =
    StateNotifierProvider<LanguageChosenNotifier, bool?>((ref) => LanguageChosenNotifier());
