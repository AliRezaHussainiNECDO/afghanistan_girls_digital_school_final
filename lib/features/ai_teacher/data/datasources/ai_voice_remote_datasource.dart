import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/network/api_client.dart';

/// سرویس صدای معلم AI — کاملاً ماژولار و Fail-safe: هر متد در صورت خطا
/// (سرور پیکربندی‌نشده، شبکه، فرمت) به‌جای پرتاب استثنا، `null` برمی‌گرداند
/// تا تجربهٔ متنی معلم AI هرگز آسیب نبیند (اصل بخش ۲۱.۴ سند).
///
///  • [transcribe]  گفتار → متن  (`POST /ai-teacher/stt` — Whisper)
///  • [synthesize]  متن → فایل صوتی محلی  (`POST /ai-teacher/tts` — صدای خانم دری)
class AiVoiceRemoteDataSource {
  final ApiClient _api;
  AiVoiceRemoteDataSource(this._api);

  /// مسیر فایل صوتی ضبط‌شده (m4a) → متن دری. `null` اگر تبدیل ممکن نبود.
  Future<String?> transcribe(String audioPath) async {
    try {
      final file = File(audioPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      final res = await _api.raw.post(
        '/ai-teacher/stt',
        data: Stream<List<int>>.fromIterable([bytes]),
        options: Options(
          contentType: 'audio/m4a',
          responseType: ResponseType.json,
          headers: {Headers.contentLengthHeader: bytes.length},
        ),
      );
      final data = res.data;
      final text = (data is Map ? data['text'] as String? : null)?.trim();
      return (text == null || text.isEmpty) ? null : text;
    } catch (_) {
      return null; // Fail-safe
    }
  }

  /// متن → مسیر فایل mp3 محلی برای پخش. `null` اگر تولید صدا ممکن نبود.
  Future<String?> synthesize(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    try {
      final res = await _api.raw.post(
        '/ai-teacher/tts',
        data: {'text': trimmed},
        options: Options(
          contentType: 'application/json',
          responseType: ResponseType.bytes,
        ),
      );
      final bytes = (res.data as List).cast<int>();
      if (bytes.isEmpty) return null;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/ai_tts_${DateTime.now().millisecondsSinceEpoch}.mp3';
      await File(path).writeAsBytes(bytes);
      return path;
    } catch (_) {
      return null; // Fail-safe
    }
  }
}
