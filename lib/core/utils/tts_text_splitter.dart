/// ابزار مشترکِ تقسیم متن برای TTS — «قاعدهٔ تضمینی» طبق درخواستِ صریحِ
/// صاحب پروژه: هیچ قطعه‌ای، تحت هیچ شرایطی، هرگز از [maxLen] بزرگ‌تر
/// نمی‌شود؛ پس زمانِ تولیدِ صدا برای هر درخواست همیشه محدود می‌ماند — مهم
/// نیست متنِ اصلی چقدر طولانی باشد.
///
/// رفع اشکالِ ریشه‌ایِ اخیر («صدای متن طولانی پلی نمی‌شود، حتی بعد از رفعِ
/// درسِ نصاب»): این منطق اول فقط داخل `LessonDetailScreen` (دکمهٔ «شنیدنِ
/// درس») پیاده شده بود. اما جای دیگری از اپ هم متنِ آزاد و بدون‌سقف را
/// مستقیم به `AiVoiceRemoteDataSource.synthesize` می‌فرستد: دکمهٔ 🔊 روی هر
/// پیامِ معلمِ هوشمند در `AiVoiceAskSheet` (`_speak`) — که پاسخِ کامل و
/// بی‌شکسته‌ی معلم را در یک درخواستِ تنها می‌فرستاد. برای پاسخ‌های طولانی
/// دقیقاً همان علامتِ قبلی («چند لحظه صبر … پیامِ در دسترس نیست») دوباره رخ
/// می‌داد — چون این مسیرِ دوم هرگز از این قاعده پیروی نمی‌کرد. راه‌حل: این
/// منطق یک‌بار اینجا نوشته شده و هر دو مسیر (`LessonDetailScreen` و
/// `AiVoiceAskSheet`) از همینِ یک تابع استفاده می‌کنند — تا اگر بعداً جای
/// سومی هم صدا اضافه شد، همین قاعده خودکار رعایت شود، نه اینکه دوباره
/// جداگانه (و احتمالاً فراموش) پیاده‌سازی شود.
library;

/// تقسیم [text] به قطعه‌های کوتاه، ترجیحاً در مرز جمله‌ها.
///
/// رفع اشکالِ دوم (اوت ۲۰۲۶، طبقِ شواهدِ `wrangler tail`): حتی بعد از
/// محدودکردنِ هر قطعه به حداکثر ۹۰۰حرف، *همهٔ* درخواست‌های TTS بدون
/// استثنا روی سقفِ Timeout سرور می‌خوردند — یعنی تولیدِ صدا برای متنِ
/// این‌قدر بزرگ هنوز خیلی کند بود. سقفِ پیش‌فرض به ۴۵۰ کاهش یافت تا
/// زمانِ تولیدِ هر درخواست کوتاه‌تر (و احتمالِ موفقیت بیشتر) شود — این
/// عدد باید با راهنماییِ سمت سرور (`GEMINI_TTS_FETCH_TIMEOUT_MS` در
/// backend/src/lib/gemini.ts) هماهنگ بماند.
List<String> splitForTts(String text, {int maxLen = 450}) {
  final sentences = text.split(RegExp(r'(?<=[.!?؟।۔\n])\s*'));
  final chunks = <String>[];
  final buf = StringBuffer();
  void flush() {
    final piece = buf.toString().trim();
    if (piece.isNotEmpty) chunks.add(piece);
    buf.clear();
  }

  for (final raw in sentences) {
    final s = raw.trim();
    if (s.isEmpty) continue;
    if (s.length > maxLen) {
      // یک «جمله» به‌تنهایی از سقف بزرگ‌تر است — قاعده اجازهٔ استثنا
      // نمی‌دهد؛ اول قطعهٔ در حالِ ساخت را ببند، بعد همین جمله را جداگانه
      // و با طولِ تضمین‌شده بشکن.
      flush();
      chunks.addAll(_hardSplitForTts(s, maxLen));
      continue;
    }
    if (buf.length + s.length > maxLen && buf.isNotEmpty) flush();
    buf.write('$s ');
  }
  flush();
  return chunks;
}

/// شکستنِ یک رشتهٔ طولانیِ بدونِ مرزِ جمله (که خودش از [maxLen] بزرگ‌تر
/// است) به قطعه‌های کوچک‌تر، فقط از مرز کلمه‌ها — تا حد امکان طبیعی
/// به‌نظر برسد. یک کلمهٔ تنهای غیرعادی‌طولانی (مثلاً یک URL) هم با طولِ
/// ثابت شکسته می‌شود، تا خروجیِ این تابع هرگز — بدون هیچ استثنا — از
/// [maxLen] بزرگ‌تر نشود.
List<String> _hardSplitForTts(String text, int maxLen) {
  final words = text.split(RegExp(r'\s+'));
  final out = <String>[];
  final buf = StringBuffer();
  for (final w in words) {
    if (w.isEmpty) continue;
    if (w.length > maxLen) {
      if (buf.isNotEmpty) {
        out.add(buf.toString().trim());
        buf.clear();
      }
      var start = 0;
      while (start < w.length) {
        final end = (start + maxLen < w.length) ? start + maxLen : w.length;
        out.add(w.substring(start, end));
        start = end;
      }
      continue;
    }
    if (buf.length + w.length + 1 > maxLen && buf.isNotEmpty) {
      out.add(buf.toString().trim());
      buf.clear();
    }
    buf.write('$w ');
  }
  if (buf.isNotEmpty) out.add(buf.toString().trim());
  return out;
}
