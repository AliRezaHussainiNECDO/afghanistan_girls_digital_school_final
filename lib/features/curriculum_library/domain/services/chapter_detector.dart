import 'package:syncfusion_flutter_pdf/pdf.dart';

/// یک فصل شناسایی‌شده از یک کتاب PDF — عنوان دقیق فصل + کل متن آن فصل
/// (تا شروع عنوان فصل بعدی) + شمارهٔ صفحهٔ شروع (برای اشکال‌زدایی/نمایش).
class DetectedChapter {
  final String title;
  final String content;
  final int pageStart;

  const DetectedChapter({
    required this.title,
    required this.content,
    required this.pageStart,
  });
}

/// شناسایی هوشمند عناوین فصل در یک کتاب درسی PDF (بدون نیاز به قالب ثابت).
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
/// اگر با اطمینان کافی («حداقل ۲ فصل واقعی») چیزی یافت نشود، لیست خالی
/// برمی‌گردد — در این حالت سمت فراخوان باید به رفتار قبلی (بدون فصل‌بندی
/// خودکار، فقط کتابخانهٔ معلم هوشمند) برگردد.
class ChapterDetector {
  ChapterDetector._();

  static final RegExp _chapterWordPattern = RegExp(
    r'^\s*(فصل|بخش|باب|چپتر|درس|Chapter|Unit)\s*[:\-–—]?\s*[\d۰-۹IVXLCM]*\s*[:\-–—]?\s*',
    caseSensitive: false,
  );

  /// نسبت حداقلی فونت خط نسبت به میانهٔ فونت سند تا «بزرگ» شمرده شود.
  static const double _fontSizeRatioThreshold = 1.18;

  /// heading معمولاً یک خط کوتاه است، نه یک پاراگراف.
  static const int _maxTitleLength = 90;

  /// حداقل فاصلهٔ خطی بین دو عنوان فصل متوالی — برای رد کردن فهرست مطالب.
  static const int _minLinesBetween = 12;

  /// حداقل تعداد فصل شناسایی‌شده تا نتیجه «قابل‌اعتماد» شمرده شود.
  static const int _minChaptersToTrust = 2;

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
      final content = lines
          .sublist(startIdx, endIdx)
          .map((l) => l.text.trim())
          .where((t) => t.isNotEmpty)
          .join('\n');
      chapters.add(DetectedChapter(
        title: title.isEmpty ? 'فصل ${k + 1}' : title,
        content: content,
        pageStart: lines[startIdx].pageIndex,
      ));
    }
    return chapters;
  }
}
