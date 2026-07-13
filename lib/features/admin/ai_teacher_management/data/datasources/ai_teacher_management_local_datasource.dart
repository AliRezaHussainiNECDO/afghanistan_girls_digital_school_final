import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../../shared_models/subject.dart';
import '../../domain/entities/ai_teacher_config.dart';

/// تنظیمات شخصیت معلم هوشمند هر مضمون — به‌صورت محلی و پایدار ذخیره
/// می‌شود (قبلاً فقط در حافظهٔ موقت بود و با هر بارگذاری مجدد پاک می‌شد).
class AiTeacherManagementLocalDataSource {
  static const _storageKey = 'ai_teacher_personas_v1';

  const AiTeacherManagementLocalDataSource();

  AiTeacherConfig _defaultFor(dynamic s) => AiTeacherConfig(
        subjectId: s.id as String,
        subjectNameFa: s.nameFa as String,
        personaDescription: 'دقیق و قدم‌به‌قدم، با مثال‌های بومی افغانستان.',
        promptVersion: 1,
      );

  Future<Map<String, AiTeacherConfig>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final defaults = {for (final s in mockSubjects) s.id: _defaultFor(s)};
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final j = Map<String, dynamic>.from(entry.value as Map);
        defaults[entry.key] = AiTeacherConfig(
          subjectId: j['subjectId'] as String,
          subjectNameFa: j['subjectNameFa'] as String,
          personaDescription: j['personaDescription'] as String,
          promptVersion: j['promptVersion'] as int? ?? 1,
        );
      }
      return defaults;
    } catch (_) {
      return defaults;
    }
  }

  Future<void> _writeAll(Map<String, AiTeacherConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final asJson = configs.map((key, c) => MapEntry(key, {
          'subjectId': c.subjectId,
          'subjectNameFa': c.subjectNameFa,
          'personaDescription': c.personaDescription,
          'promptVersion': c.promptVersion,
        }));
    await prefs.setString(_storageKey, jsonEncode(asJson));
  }

  Future<List<AiTeacherConfig>> getConfigs() async {
    await Future.delayed(const Duration(milliseconds: 200));
    final all = await _readAll();
    return mockSubjects.map((s) => all[s.id] ?? _defaultFor(s)).toList();
  }

  Future<void> updatePersona(String subjectId, String newDescription) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final all = await _readAll();
    final current = all[subjectId];
    if (current != null) {
      all[subjectId] = AiTeacherConfig(
        subjectId: current.subjectId,
        subjectNameFa: current.subjectNameFa,
        personaDescription: newDescription,
        promptVersion: current.promptVersion + 1,
      );
      await _writeAll(all);
    }
  }
}
