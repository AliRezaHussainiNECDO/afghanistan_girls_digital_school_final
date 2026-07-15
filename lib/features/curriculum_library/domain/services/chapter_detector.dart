import 'package:syncfusion_flutter_pdf/pdf.dart';

/// یک «درس» شناسایی‌شده درون یک فصل — عنوان کوتاه + متن همان بخش.
class DetectedLesson {
  final String title;
  final String content;

  const DetectedLesson({required this.title, required this.content});
}

/// یک فصل شناسایی‌شده از یک کتاب PDF — عنوان دقیق فصل + فهرست درس‌های آن
/// (هرگز یک بلوکِ غول‌آسای تک‌درسی؛ همیشه به چند درسِ کوتاه‌تر و قابل‌مطالعه
/// تقسیم می‌شود) + شمارهٔ صفحهٔ شروع (برای اشکال‌زدایی/نمایش).
class DetectedChapter {
  final String title;
  final List<DetectedLesson> lessons;
  final int pageStart;

  const DetectedChapter({
    required this.title,
    required this.lessons,
    required this.pageStart,
  });
}

/// شناسایی هوشمند عناوین فصل (و درس‌های داخل هر فصل) در یک کتاب درسی PDF
/// (بدون نیاز به قالب ثابت).
///
/// دو سرنخ مستقل با هم ترکیب می‌شوند تا خط «عنوان فصل واقعی» از متن عادی
/// جدا شود:
///
///  ۱) **الگوی متنی**: خطی که با «فصل»، «بخش»، «باب» یا معادل انگلیسی
///     «Chapter» شروع می‌شود (به‌همراه شمارهٔ فارسی یا انگلیسی اختیاری).
///  ۲) **اندازهٔ فونت**: عنوان‌ها معمولاً با فونتی به‌وضوح بزرگ‌تر از میانهٔ
///     فونت کل سند چاپ می‌شوند — این سرنخ به زبان/الگوی خاصی وابسته نیست
///     و کتاب‌هایی را هم پوشش می‌دهد که کلمهٔ «فصل» را در عنوان نمی‌آورند.
///
/// برای جلوگیری از تشخیص کاذبِ فهرست مطالب (که در آن عنوان‌های همهٔ فصل‌ها
/// پشت‌سرهم و با فاصلهٔ کم می‌آیند)، دو کاندید که کمتر از [_minLinesBetween]
/// خط از هم فاصله دارند در یک خوشه ادغام می‌شوند و فقط اولین‌شان نگه
/// داشته می‌شود.
///
/// **گام دوم (تازه):** متن هر فصل خودش دوباره برای عنوان‌های «درس» بررسی
/// می‌شود (کلمهٔ «درس»/«Lesson» + همان سرنخ فونت). اگر عنوان درسِ قابل‌اعتماد
/// یافت نشود، متن فصل بر اساس طول به چند قطعهٔ خوانا (نه یک دیوار متن)
/// تقسیم می‌شود — طبق درخواست صریح کاربر که محتوای آپلودشده باید همیشه به
/// شکل «درس‌های» جداگانه و زیبا نمایش داده شود، نه یک بلوک خام و زشت.
///
/// اگر با اطمینان کافی («حداقل ۲ فصل واقعی») چیزی یافت نشود، لیست خالی
/// برمی‌گردد — در این حالت سمت فراخوان باید به رفتار قبلی (بدون فصل‌بندی
/// خودکار، فقط کتابخانهٔ معلم هوشمند) برگردد.
class ChapterDetector {
  ChapterDetector._();

  static final RegExp _chapterWordPattern = RegExp(
    r'^\s*(فصل|بخش|باب|چپتر|Chapter|Unit)\s*[:\-–—]?\s*[\d۰-۹IVXLCM]*\s*[:\-–—]?\s*',
    caseSensitive: false,
  );

  static final RegExp _lessonWordPattern = RegExp(
    r'^\s*(درس|مبحث|گفتار|Lesson)\s*[:\-–—]?\s*[\d۰-۹]*\s*[:\-–—]?\s*',
    caseSensitive: false,
  );

  /// خطوطی که فقط شمارهٔ صفحه/جداکنندهٔ تزئینی‌اند — از متن نهایی درس حذف می‌شوند.
  static final RegExp _pageNoiseLine = RegExp(r'^[\d۰-۹\s\-–—._]{1,4}$');

  /// نسبت حداقلی فونت خط نسبت به میانهٔ فونت سند تا «بزرگ» شمرده شود.
  static const double _fontSizeRatioThreshold = 1.18;

  /// heading معمولاً یک خط کوتاه است، نه یک پاراگراف.
  static const int _maxTitleLength = 90;

  /// حداقل فاصلهٔ خطی بین دو عنوان فصل متوالی — برای رد کردن فهرست مطالب.
  static const int _minLinesBetween = 12;

  /// حداقل فاصلهٔ خطی بین دو عنوان درس متوالی داخل یک فصل.
  static const int _minLessonLinesBetween = 4;

  /// حداقل تعداد فصل/درس شناسایی‌شده تا نتیجه «قابل‌اعتماد» شمرده شود.
  static const int _minChaptersToTrust = 2;
  static const int _minLessonsToTrust = 2;

  /// حداکثر طول هر «درسِ» بدون‌عنوان هنگام تقسیم بر اساس طول (نویسه) —
  /// تضمین می‌کند هیچ‌وقت یک درس بیش‌ازحد بلند/زشت نمایش داده نشود.
  static const int _maxChunkChars = 1200;

  static List<DetectedChapter> detect(PdfDocument document) {
    List<TextLine> lines;
    try {
      lines = PdfTextExtractor(document).extractTextLines();
    } catch (_) {
      return const [];
    }
    if (lines.isEmpty) return const [];

    final fontSizes = lines.map((l) => l.fontSize).where((s) => s > 0).toList()..sort();
    final medianFont = fontSizes.isEmpty ? 12.0 : fontSizes[fontSizes.length ~/ 2];

    bool byWord(int i) => _chapterWordPattern.hasMatch(lines[i].text.trim());
    bool byFont(int i) => medianFont > 0 && lines[i].fontSize >= medianFont * _fontSizeRatioThreshold;
    bool isShortEnough(int i) {
      final t = lines[i].text.trim();
      return t.isNotEmpty && t.length <= _maxTitleLength;
    }

    // قوی‌ترین سرنخ: هر دو (کلمهٔ فصل + فونت بزرگ) با هم.
    var chosen = <int>[
      for (var i = 0; i < lines.length; i++)
        if (isShortEnough(i) && byWord(i) && byFont(i)) i,
    ];
    // اگر کافی نبود، فقط الگوی کلمه‌ای (کتاب‌هایی با فونت یک‌دست).
    if (chosen.length < _minChaptersToTrust) {
      chosen = [
        for (var i = 0; i < lines.length; i++)
          if (isShortEnough(i) && byWord(i)) i,
      ];
    }
    // اگر همچنان کافی نبود، فقط فونت بزرگ (کتاب‌هایی با عنوان بدون کلمهٔ «فصل»).
    if (chosen.length < _minChaptersToTrust) {
      chosen = [
        for (var i = 0; i < lines.length; i++)
          if (isShortEnough(i) && byFont(i)) i,
      ];
    }
    if (chosen.length < _minChaptersToTrust) return const [];

    // ادغام کاندیدهای خیلی نزدیک به هم (فهرست مطالب) — فقط اولین هر خوشه می‌ماند.
    final deduped = <int>[];
    for (final idx in chosen) {
      if (deduped.isEmpty || idx - deduped.last >= _minLinesBetween) {
        deduped.add(idx);
      }
    }
    if (deduped.length < _minChaptersToTrust) return const [];

    final chapters = <DetectedChapter>[];
    for (var k = 0; k < deduped.length; k++) {
      final startIdx = deduped[k];
      final endIdx = k + 1 < deduped.length ? deduped[k + 1] : lines.length;
      final title = lines[startIdx].text.trim();
      final bodyLines = lines.sublist(startIdx + 1, endIdx);
      final lessons = _splitIntoLessons(bodyLines, medianFont);
      if (lessons.isEmpty) continue; // فصل بدون هیچ محتوای واقعی — نادیده گرفته می‌شود
      chapters.add(DetectedChapter(
        title: title.isEmpty ? 'فصل ${k + 1}' : title,
        lessons: lessons,
        pageStart: lines[startIdx].pageIndex,
      ));
    }
    return chapters;
  }

  /// متن یک فصل را به «درس»‌های واقعی (اگر عنوان درس در متن باشد) یا در غیر
  /// این صورت به قطعه‌های کوتاه و خواناتقسیم می‌کند — خروجی هرگز یک بلوک
  /// خامِ تک‌پارچه نیست.
  static List<DetectedLesson> _splitIntoLessons(List<TextLine> bodyLines, double medianFont) {
    if (bodyLines.isEmpty) return const [];

    bool isShort(String t) => t.isNotEmpty && t.length <= _maxTitleLength;
    bool byWord(int i) => _lessonWordPattern.hasMatch(bodyLines[i].text.trim());
    bool byFont(int i) =>
        medianFont > 0 && bodyLines[i].fontSize >= medianFont * _fontSizeRatioThreshold;

    var candidates = <int>[
      for (var i = 0; i < bodyLines.length; i++)
        if (isShort(bodyLines[i].text.trim()) && byWord(i)) i,
    ];
    if (candidates.length < _minLessonsToTrust) {
      // سرنخ دوم: زیرعنوان با فونت به‌وضوح بزرگ‌تر از متن معمولی (حتی بدون کلمهٔ «درس»).
      candidates = [
        for (var i = 0; i < bodyLines.length; i++)
          if (isShort(bodyLines[i].text.trim()) && byFont(i)) i,
      ];
    }

    final deduped = <int>[];
    for (final idx in candidates) {
      if (deduped.isEmpty || idx - deduped.last >= _minLessonLinesBetween) {
        deduped.add(idx);
      }
    }

    if (deduped.length >= _minLessonsToTrust) {
      final lessons = <DetectedLesson>[];
      for (var k = 0; k < deduped.length; k++) {
        final start = deduped[k];
        final end = k + 1 < deduped.length ? deduped[k + 1] : bodyLines.length;
        final title = bodyLines[start].text.trim();
        final content = _cleanJoin(bodyLines.sublist(start, end));
        if (content.trim().isEmpty) continue;
        lessons.add(DetectedLesson(title: title.isEmpty ? 'درس ${k + 1}' : title, content: content));
      }
      if (lessons.length >= _minLessonsToTrust) return lessons;
    }

    // بدون عنوان درسِ قابل‌اعتماد → تقسیم بر اساس طول، همیشه چند قطعهٔ کوتاه.
    return _chunkByLength(bodyLines);
  }

  static String _cleanJoin(List<TextLine> ls) {
    final buf = <String>[];
    for (final l in ls) {
      final t = l.text.trim();
      if (t.isEmpty || _pageNoiseLine.hasMatch(t)) continue;
      buf.add(t);
    }
    return buf.join('\n');
  }

  static List<DetectedLesson> _chunkByLength(List<TextLine> bodyLines) {
    final cleanedLines = <String>[
      for (final l in bodyLines)
        if (l.text.trim().isNotEmpty && !_pageNoiseLine.hasMatch(l.text.trim())) l.text.trim(),
    ];
    if (cleanedLines.isEmpty) return const [];

    final lessons = <DetectedLesson>[];
    final buf = StringBuffer();
    var count = 0;
    for (final line in cleanedLines) {
      if (buf.length + line.length > _maxChunkChars && buf.isNotEmpty) {
        count += 1;
        lessons.add(DetectedLesson(title: 'درس $count', content: buf.toString().trim()));
        buf.clear();
      }
      buf.writeln(line);
    }
    if (buf.isNotEmpty) {
      count += 1;
      lessons.add(DetectedLesson(title: 'درس $count', content: buf.toString().trim()));
    }

    // اگر آخرین قطعه خیلی کوتاه ماند (مثلاً چند سطر آخر فصل)، به قطعهٔ قبلی می‌چسبد
    // تا «درسِ» بی‌محتوا/خیلی کوتاه نداشته باشیم.
    if (lessons.length >= 2 && lessons.last.content.length < 150) {
      final last = lessons.removeLast();
      final prev = lessons.removeLast();
      lessons.add(DetectedLesson(title: prev.title, content: '${prev.content}\n${last.content}'));
    }
    return lessons;
  }
}
