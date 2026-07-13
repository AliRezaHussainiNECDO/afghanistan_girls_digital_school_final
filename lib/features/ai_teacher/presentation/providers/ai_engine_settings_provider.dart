import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// تنظیمات موتور هوش مصنوعی — طبق تصمیم کاربر، به‌صورت پیش‌فرض خاموش است
/// (موتور محلی رایگان فعال است) و فقط با فعال‌سازی دستی مدیر و نصب Ollama
/// روی کامپیوتر، هوش مصنوعی واقعی وارد کار می‌شود.
class AiEngineSettings {
  final bool useOllama;
  final String baseUrl;
  final String model;

  const AiEngineSettings({
    this.useOllama = false,
    this.baseUrl = 'http://localhost:11434',
    this.model = 'llama3.1',
  });

  AiEngineSettings copyWith({bool? useOllama, String? baseUrl, String? model}) => AiEngineSettings(
        useOllama: useOllama ?? this.useOllama,
        baseUrl: baseUrl ?? this.baseUrl,
        model: model ?? this.model,
      );
}

class AiEngineSettingsNotifier extends StateNotifier<AiEngineSettings> {
  static const _kUse = 'ai_engine_use_ollama';
  static const _kUrl = 'ai_engine_base_url';
  static const _kModel = 'ai_engine_model';

  AiEngineSettingsNotifier() : super(const AiEngineSettings()) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = AiEngineSettings(
      useOllama: prefs.getBool(_kUse) ?? false,
      baseUrl: prefs.getString(_kUrl) ?? 'http://localhost:11434',
      model: prefs.getString(_kModel) ?? 'llama3.1',
    );
  }

  Future<void> update({bool? useOllama, String? baseUrl, String? model}) async {
    state = state.copyWith(useOllama: useOllama, baseUrl: baseUrl, model: model);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUse, state.useOllama);
    await prefs.setString(_kUrl, state.baseUrl);
    await prefs.setString(_kModel, state.model);
  }
}

final aiEngineSettingsProvider =
    StateNotifierProvider<AiEngineSettingsNotifier, AiEngineSettings>(
  (ref) => AiEngineSettingsNotifier(),
);
