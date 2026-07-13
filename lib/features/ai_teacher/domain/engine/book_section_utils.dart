import '../../../curriculum_library/domain/entities/curriculum_book.dart';

/// ابزارهای تقسیم متن کتاب به بخش‌های قابل‌تدریس و جست‌وجوی ساده — پایهٔ
/// «RAG محلی» بدون نیاز به سرویس هوش مصنوعی خارجی. طبق درخواست کاربر:
/// معلم هوشمند باید واقعاً از روی متن کتاب تدریس/سؤال/مثال بدهد.
class BookSectionUtils {
  BookSectionUtils._();

  static const int sentencesPerSection = 6;

  /// جدا کردن متن به جملات فارسی/دری (با در نظر گرفتن علائم .!؟۔).
  static List<String> splitSentences(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return [];
    final parts = normalized.split(RegExp(r'(?<=[\.\!\؟\۔])\s+'));
    return parts.map((p) => p.trim()).where((p) => p.length > 8).toList();
  }

  /// تقسیم یک کتاب به بخش‌های ~۶ جمله‌ای، هر بخش یک «واحد تدریس».
  static List<BookSection> splitIntoSections(CurriculumBook book) {
    final sentences = splitSentences(book.extractedText);
    final sections = <BookSection>[];
    for (var i = 0; i < sentences.length; i += sentencesPerSection) {
      final chunk = sentences.skip(i).take(sentencesPerSection).toList();
      if (chunk.isEmpty) continue;
      final content = chunk.join(' ');
      final headingSource = chunk.first;
      final heading =
          headingSource.length > 42 ? '${headingSource.substring(0, 42)}…' : headingSource;
      sections.add(BookSection(
        bookId: book.id,
        bookTitle: book.title,
        index: sections.length,
        heading: heading,
        content: content,
      ));
    }
    return sections;
  }

  static List<BookSection> sectionsForBooks(List<CurriculumBook> books) {
    final all = <BookSection>[];
    for (final book in books) {
      all.addAll(splitIntoSections(book));
    }
    return all;
  }

  static Set<String> _tokenize(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    return cleaned
        .split(RegExp(r'\s+'))
        .map((t) => t.trim())
        .where((t) => t.length >= 2)
        .toSet();
  }

  /// بهترین بخش‌های مرتبط با یک پرسش — بر اساس هم‌پوشانی سادهٔ واژگان.
  static List<BookSection> findRelevant(List<BookSection> sections, String query, {int topN = 1}) {
    final queryTokens = _tokenize(query);
    if (queryTokens.isEmpty || sections.isEmpty) return [];
    final scored = sections.map((s) {
      final sectionTokens = _tokenize(s.content + ' ' + s.heading);
      final overlap = queryTokens.intersection(sectionTokens).length;
      return MapEntry(s, overlap);
    }).where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return scored.take(topN).map((e) => e.key).toList();
  }

  /// یک جملهٔ «نمونه/مثال» از داخل بخش — اگر واژهٔ «مثال» در متن باشد همان را
  /// می‌آورد، در غیر این صورت یک جملهٔ متفاوت از توضیح اصلی انتخاب می‌کند.
  static String pickExampleSentence(BookSection section, {String? excludeSentence}) {
    final sentences = splitSentences(section.content);
    if (sentences.isEmpty) return section.content;
    final withExampleWord = sentences.firstWhere(
      (s) => s.contains('مثال') || s.contains('مثلاً') || s.contains('نمونه'),
      orElse: () => '',
    );
    if (withExampleWord.isNotEmpty) return withExampleWord;
    final candidates = sentences.where((s) => s != excludeSentence).toList();
    if (candidates.length > 1) return candidates[candidates.length ~/ 2];
    return sentences.last;
  }

  /// جمله‌ای که بیشترین «محتوای قابل‌سؤال» را دارد (عدد، تعریف، یا طولانی‌تر
  /// از میانگین) — برای ساخت سؤال درک مطلب استفاده می‌شود.
  static String pickQuestionSourceSentence(BookSection section) {
    final sentences = splitSentences(section.content);
    if (sentences.isEmpty) return section.content;
    final withNumber = sentences.where((s) => RegExp(r'[0-9۰-۹]').hasMatch(s)).toList();
    if (withNumber.isNotEmpty) return withNumber.first;
    sentences.sort((a, b) => b.length.compareTo(a.length));
    return sentences.first;
  }
}
