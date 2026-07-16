import 'package:syncfusion_flutter_pdf/pdf.dart';

/// یک خط استخراج‌شده از PDF، به همراه متنِ **اصلاح‌شده** (نه خام) — تا کل
/// این فایل به‌جای `TextLine.text` خام (که برای برخی PDFهای دری/پشتو
/// نویسه‌های هر کلمه را معکوس برمی‌گرداند، مثلاً «ایمیک» به‌جای «کیمیا»)
/// همیشه از متن خواناشده استفاده کند. `fontSize`/`pageIndex` عیناً از
/// `TextLine` منبع می‌آیند (برای سرنخ فونت/شمارهٔ صفحه).
class OrderedLine {
  final String text;
  final double fontSize;
  final int pageIndex;

  const OrderedLine({required this.text, required this.fontSize, required this.pageIndex});
}

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

  /// خطوط سند به ترتیب واقعیِ خواندن (صفحه‌به‌صفحه، از بالا به پایین) —
  /// منبع مشترک هم برای تشخیص فصل و هم برای متن کامل ذخیره‌شدهٔ کتاب.
  ///
  /// چرا لازم است: برخی PDFها (به‌خصوص کتاب‌های رسمی دری/پشتو با چیدمان
  /// پیچیده) وقتی با متد سادهٔ `extractText()` به‌صورت یک‌جا خوانده می‌شوند،
  /// ترتیب خط‌ها را جابه‌جا برمی‌گردانند (مثلاً چند خط پیاپی یک پاراگراف
  /// برعکس/قاطی می‌شوند) — نتیجه‌اش متنی درهم‌ریخته در «مشاهدهٔ درس» شاگرد
  /// است. `extractTextLines()` موقعیت هندسی هر خط را هم می‌دهد؛ با
  /// مرتب‌سازی صریح بر اساس صفحه سپس فاصلهٔ عمودی از بالای صفحه، ترتیب خط‌ها
  /// همیشه با ترتیب واقعی چاپ‌شده یکی می‌ماند — چه برای تشخیص فصل استفاده
  /// شود چه برای متن کامل ذخیره‌شده (یکسان‌سازی منبع استخراج، رفع اشکال
  /// «متن نامنظم»).
  static List<OrderedLine> extractOrderedLines(PdfDocument document) {
    final lines = PdfTextExtractor(document).extractTextLines();
    final sorted = List<TextLine>.from(lines)
      ..sort((a, b) {
        final byPage = a.pageIndex.compareTo(b.pageIndex);
        if (byPage != 0) return byPage;
        return a.bounds.top.compareTo(b.bounds.top);
      });

    // یک‌بار روی یک نمونه (نه کل سند، برای سرعت) تصمیم می‌گیریم که آیا این
    // PDF مشخصاً به مشکل «نویسه‌های معکوس» دچار است یا نه، و همان تصمیم را
    // یکسان روی همهٔ خط‌ها اعمال می‌کنیم — هر PDF ممکن است رفتار متفاوتی
    // داشته باشد (بعضی درست، بعضی معکوس)، پس هرگز کورکورانه فرض نمی‌کنیم.
    final sample = sorted.take(400).map((l) => l.text).join(' ');
    final needsFix = _looksReversed(sample);

    return sorted
        .map((l) => OrderedLine(
              text: needsFix ? fixRtlRunOrder(l.text) : l.text,
              fontSize: l.fontSize,
              pageIndex: l.pageIndex,
            ))
        .toList();
  }

  /// چند کلمهٔ خیلی پرکاربرد دری/فارسی — برای سنجش «خواناتر بودن» یک متن
  /// بدون نیاز به فرهنگ لغت کامل. اگر این کلمات در نسخهٔ اصلاح‌شده به‌وضوح
  /// بیشتر از نسخهٔ خام دیده شوند، متن واقعاً معکوس بوده است.
  static const List<String> _commonWords = [
    'است', 'در', 'از', 'به', 'که', 'این', 'را', 'با', 'برای', 'هم', 'یک', 'می',
  ];

  /// شمارش دستیِ رخداد هر «کلمهٔ کامل» (نه زیررشته‌ای داخل کلمهٔ دیگر) —
  /// عمداً بدون lookbehind/`\p{L}` نوشته شده تا به هیچ رفتار خاصِ موتور
  /// RegExp وابسته نباشد و روی هر نسخهٔ Dart قابل‌اتکا کار کند.
  static bool _isArabicLetter(int rune) => _isArabicScript(rune);

  static int _commonWordScore(String text) {
    var score = 0;
    for (final w in _commonWords) {
      var searchFrom = 0;
      while (true) {
        final idx = text.indexOf(w, searchFrom);
        if (idx == -1) break;
        final before = idx > 0 ? text.codeUnitAt(idx - 1) : null;
        final afterIdx = idx + w.length;
        final after = afterIdx < text.length ? text.codeUnitAt(afterIdx) : null;
        final boundaryBefore = before == null || !_isArabicLetter(before);
        final boundaryAfter = after == null || !_isArabicLetter(after);
        if (boundaryBefore && boundaryAfter) score++;
        searchFrom = idx + w.length;
      }
    }
    return score;
  }

  /// آیا این نمونه‌متن مشخصاً به شکل معکوس ذخیره شده — با مقایسهٔ بسامد
  /// کلمات پرکاربرد دری در حالت خام در برابر حالتِ [fixRtlRunOrder]. این
  /// تصمیم خود-تصحیح‌گر است: متنِ از قبل درست هرگز به‌اشتباه خراب نمی‌شود،
  /// چون در آن حالت نسخهٔ «اصلاح‌شده» امتیاز کمتری می‌گیرد، نه بیشتر.
  static bool _looksReversed(String sample) {
    if (sample.trim().isEmpty) return false;
    final originalScore = _commonWordScore(sample);
    final fixedScore = _commonWordScore(fixRtlRunOrder(sample));
    return fixedScore > originalScore;
  }

  /// محدودهٔ نویسه‌های عربی/دری/پشتو (شامل اعداد اختیاری دری در همان بلوک) —
  /// برای تشخیص «قطعهٔ راست‌به‌چپ» در [fixRtlRunOrder].
  static bool _isArabicScript(int rune) =>
      (rune >= 0x0600 && rune <= 0x06FF) || // Arabic (+ اعداد دری ۰-۹)
      (rune >= 0x0750 && rune <= 0x077F) || // Arabic Supplement
      (rune >= 0x08A0 && rune <= 0x08FF) || // Arabic Extended-A
      (rune >= 0xFB50 && rune <= 0xFDFF) || // Arabic Presentation Forms-A
      (rune >= 0xFE70 && rune <= 0xFEFF); // Arabic Presentation Forms-B

  /// رفع اشکال «متن نامنظم/بی‌مفهوم»: برخی PDFهای رسمی دری/پشتو (بسته به
  /// ابزار تولیدشان) هر کلمه را در جریان محتوای PDF به ترتیب بصری
  /// چپ‌به‌راست ذخیره می‌کنند، نه ترتیب منطقی راست‌به‌چپ — استخراج خام
  /// Syncfusion همان ترتیب معکوس را برمی‌گرداند (مثلاً «ایمیک» به‌جای
  /// «کیمیا»، یا «ناغفا» به‌جای «افغان»). اعداد لاتین/انگلیسی (مثل سال
  /// ۱۳۹۸) از این اشکال مصون‌اند چون در بلوک یونیکد جداگانه‌ای هستند.
  ///
  /// این تابع هر قطعهٔ پیوستهٔ نویسهٔ عربی/دری/پشتو (یعنی هر «کلمه») را در
  /// خودش معکوس می‌کند — بدون دست‌زدن به فاصله‌ها، اعداد لاتین، یا ترتیب
  /// کلمات در خط — تا متن دوباره خوانا شود. این تابع Idempotent نیست (روی
  /// متنی که یک‌بار از آن عبور کرده، دوباره صدا زدنش دوباره معکوسش می‌کند)،
  /// به همین دلیل هرگز به‌صورت کورکورانه روی همهٔ PDFها اعمال نمی‌شود:
  /// [extractOrderedLines] ابتدا با [_looksReversed] روی یک نمونه از سند
  /// تصمیم می‌گیرد که آیا اصلاً لازم است، و فقط در آن صورت این تابع را
  /// یک‌بار برای هر خط صدا می‌زند — تا PDFهایی که از قبل درست استخراج
  /// می‌شوند هرگز به‌اشتباه خراب نشوند.
  static String fixRtlRunOrder(String line) {
    final runes = line.runes.toList();
    if (runes.isEmpty) return line;
    final buf = StringBuffer();
    var i = 0;
    while (i < runes.length) {
      if (_isArabicScript(runes[i])) {
        var j = i + 1;
        while (j < runes.length && _isArabicScript(runes[j])) {
          j++;
        }
        for (var k = j - 1; k >= i; k--) {
          buf.writeCharCode(runes[k]);
        }
        i = j;
      } else {
        buf.writeCharCode(runes[i]);
        i++;
      }
    }
    return buf.toString();
  }

  /// نسخهٔ [detect] که روی خطوط از پیش استخراج‌شده کار می‌کند — تا وقتی متن
  /// کامل و فصل‌ها هر دو لازم‌اند، سند فقط یک‌بار استخراج شود.
  static List<DetectedChapter> detectFromLines(List<OrderedLine> lines) {
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

  /// نسخهٔ کامل (استخراج + تشخیص) برای فراخوان‌هایی که فقط فصل‌ها را
  /// می‌خواهند و به متن کامل مرتب‌شده نیازی ندارند.
  static List<DetectedChapter> detect(PdfDocument document) {
    List<OrderedLine> lines;
    try {
      lines = extractOrderedLines(document);
    } catch (_) {
      return const [];
    }
    return detectFromLines(lines);
  }

  /// متن یک فصل را به «درس»‌های واقعی (اگر عنوان درس در متن باشد) یا در غیر
  /// این صورت به قطعه‌های کوتاه و خواناتقسیم می‌کند — خروجی هرگز یک بلوک
  /// خامِ تک‌پارچه نیست.
  static List<DetectedLesson> _splitIntoLessons(List<OrderedLine> bodyLines, double medianFont) {
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

  static String _cleanJoin(List<OrderedLine> ls) {
    final buf = <String>[];
    for (final l in ls) {
      final t = l.text.trim();
      if (t.isEmpty || _pageNoiseLine.hasMatch(t)) continue;
      buf.add(t);
    }
    return buf.join('\n');
  }

  static List<DetectedLesson> _chunkByLength(List<OrderedLine> bodyLines) {
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
