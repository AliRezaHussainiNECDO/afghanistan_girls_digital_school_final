import 'package:flutter/material.dart';
import 'translations/en.dart';
import 'translations/fa.dart';
import 'translations/ps.dart';

/// سیستم سبک بومی‌سازی (بدون نیاز به build_runner/gen-l10n) — سه زبان
/// فارسی(دری)/پشتو/انگلیسی طبق اصل «دوزبانگی کامل» بخش ۱.۲ سند
/// (اینجا سه‌زبانه، چون preferred_language سه مقدار دارد: fa/ps/en).
class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static const List<Locale> supportedLocales = [
    Locale('fa'),
    Locale('ps'),
    Locale('en'),
  ];

  static AppLocalizations of(BuildContext context) {
    final instance =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(instance != null, 'AppLocalizations not found in context');
    return instance!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  Map<String, String> get _strings {
    switch (locale.languageCode) {
      case 'ps':
        return psStrings;
      case 'en':
        return enStrings;
      case 'fa':
      default:
        return faStrings;
    }
  }

  /// آیا این زبان راست‌به‌چپ است؟ (فارسی/پشتو بله، انگلیسی خیر)
  bool get isRtl => locale.languageCode == 'fa' || locale.languageCode == 'ps';

  /// ترجمهٔ یک کلید؛ در صورت نبود، خود کلید برگردانده می‌شود (Fallback ایمن).
  /// از `{param}` برای درج مقادیر پویا پشتیبانی می‌کند.
  String translate(String key, [Map<String, String>? params]) {
    var value = _strings[key] ?? key;
    if (params != null) {
      params.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['fa', 'ps', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// میان‌بر راحت: `context.tr('common.save')`
extension AppLocalizationsX on BuildContext {
  String tr(String key, [Map<String, String>? params]) =>
      AppLocalizations.of(this).translate(key, params);

  bool get isRtl => AppLocalizations.of(this).isRtl;
}
