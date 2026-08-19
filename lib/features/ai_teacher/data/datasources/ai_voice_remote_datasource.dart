import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
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

  /// متن → مسیر فایل صوتی محلی برای پخش. `null` اگر تولید صدا ممکن نبود.
  ///
  /// رفع اشکال (بعد از افزودن Gemini TTS به‌عنوان مسیر اصلی سمت سرور):
  /// قبلاً همیشه پسوند `.mp3` فرض می‌شد چون Azure/OpenAI هر دو mp3
  /// برمی‌گرداندند. Gemini TTS اما WAV برمی‌گرداند (`Content-Type: audio/wav`)
  /// — پخش‌کننده (audioplayers) بر اساس محتوای فایل تشخیص می‌دهد نه صرفاً
  /// پسوند، اما پسوند درست باعث سازگاری بیشتر روی همهٔ دستگاه‌ها می‌شود؛ پس
  /// حالا پسوند از روی Content-Type واقعی پاسخ سرور انتخاب می‌شود.
  ///
  /// رفع اشکال دوم، ریشه‌ای («متن کوتاه کار می‌کند، متن یک درس کامل بعد از
  /// چند لحظه "در دسترس نیست" می‌دهد»): علت واقعی Timeout بود، نه خرابی
  /// سرویس. `ApiClient` سراسری فقط ۲۰ ثانیه صبر می‌کند (مناسب برای
  /// درخواست‌های معمولی)، اما تولید صدا برای یک قطعهٔ ~۹۰۰حرفی (نه یک جوابِ
  /// کوتاه چت) به‌طبیعتِ خودش بیشتر طول می‌کشد. اینجا فقط برای همین یک
  /// درخواست، سقفِ صبر را جداگانه و سخاوتمندانه‌تر تنظیم می‌کنیم — سقفِ
  /// سراسریِ بقیهٔ اپ دست‌نخورده می‌ماند (تا یک سرویسِ واقعاً خراب هنوز زود
  /// خطا بدهد). این عدد باید با `GEMINI_TTS_FETCH_TIMEOUT_MS` سمت سرور
  /// (backend/src/lib/gemini.ts) هماهنگ/نزدیک بماند — الان همراهِ آن (که
  /// طبق شواهدِ `wrangler tail` به ۱۷۰ ثانیه بالا برده شد چون حتی بعد از
  /// محدودکردنِ اندازهٔ قطعه‌ها، هر درخواست دقیقاً روی ۹۰ ثانیه Timeout
  /// می‌خورد) اینجا هم بالا برده شد.
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
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 190),
        ),
      );
      final bytes = (res.data as List).cast<int>();
      if (bytes.isEmpty) return null;
      final contentType = res.headers.value('content-type') ?? '';
      final ext = contentType.contains('wav') ? 'wav' : 'mp3';
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/ai_tts_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(path).writeAsBytes(bytes);
      return path;
    } catch (e) {
      // رفع اشکالِ «نمی‌شود فهمید چرا شکست خورد»: قبلاً خطای واقعی همیشه
      // کاملاً بی‌صدا بلعیده می‌شد (`catch (_)`) — یعنی حتی وقتی درخواست
      // هرگز به سرور هم نمی‌رسید (مثلاً Timeout محلی، قطعی شبکه، یا خطای
      // ساختن درخواست)، در گزارش‌های سمت سرور (`wrangler tail`) هم هیچ ردی
      // دیده نمی‌شد — چون مشکل اصلاً هرگز از گوشی خارج نشده بود. حالا فقط
      // در Debug (هرگز در Release — بدون افت کارایی/نشتِ اطلاعات حساس)،
      // نوع دقیقِ خطا (Timeout؟ قطعیِ شبکه؟ چیز دیگر؟) در کنسول Debug چاپ
      // می‌شود — تا اگر باز هم مشکلی بود، بلافاصله (بدون حدسِ دیگر) بدانیم
      // آیا اصلاً درخواست ارسال شده یا نه.
      if (kDebugMode) {
        debugPrint('[AiVoiceRemoteDataSource.synthesize] failed for ${trimmed.length} chars — $e');
      }
      return null; // Fail-safe
    }
  }
}
