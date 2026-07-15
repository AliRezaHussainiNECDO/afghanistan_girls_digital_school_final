import 'ai_engine.dart';
import 'book_section_utils.dart';

/// موتور پیش‌فرض و رایگان معلم هوشمند — به هیچ سرویس ابری یا کلید API نیاز
/// ندارد. مستقیماً از روی متنِ کتاب‌های آپلودشدهٔ مدیر برای هر مضمون
/// «تدریس» می‌کند، «سؤال» درک مطلب می‌سازد و «مثال» واقعی از داخل کتاب
/// می‌دهد — دقیقاً طبق خواستهٔ کاربر، بدون وابستگی به بک‌اند یا هوش مصنوعی
/// نصب‌شده.
class LocalCurriculumAiEngine implements AiEngine {
  @override
  String get id => 'local_curriculum';

  static const _offTopicWords = ['سیاست', 'فوتبال', 'انتخابات', 'جنگ'];

  @override
  Future<AiEngineResponse> respond(AiEngineRequest r) async {
    // شبیه‌سازی زمان «فکر کردن» برای حس طبیعی گفتگو.
    await Future.delayed(const Duration(milliseconds: 500));

    // حالت گفتگوی آزاد (مشاور هوشمند): این موتور مبتنی بر کتاب است و پاسخ
    // آزاد ندارد؛ بدنهٔ خالی برمی‌گرداند تا لایهٔ بالاتر (AdvisorService)
    // از پاسخ‌های همدلانهٔ درون‌ساخت خودش استفاده کند — هرگز پیام «کتاب
    // آپلود نشده» به شاگرد مشاور نشان داده نمی‌شود.
    if (r.openDomain) {
      return const AiEngineResponse(body: '');
    }

    if (r.allSections.isEmpty) {
      return const AiEngineResponse(
        body:
            'هنوز کتابی برای این مضمون توسط مدیریت آپلود نشده. به‌محض آپلود کتاب رسمی نصاب تعلیمی، می‌توانم از روی همان درس بدهم، سؤال بپرسم و مثال بزنم. 📚',
      );
    }

    switch (r.intent) {
      case AiIntent.startLesson:
      case AiIntent.nextSection:
        return _teachSection(r);
      case AiIntent.giveExample:
        return _giveExample(r);
      case AiIntent.askQuestion:
        return _askQuestion(r);
      case AiIntent.answerAttempt:
        return _gradeAnswer(r);
      case AiIntent.freeQuestion:
        return _answerFreeQuestion(r);
    }
  }

  bool _isOffTopic(String text) => _offTopicWords.any((w) => text.contains(w));

  AiEngineResponse _teachSection(AiEngineRequest r) {
    final section = r.currentSection;
    if (section == null) {
      return const AiEngineResponse(
        body: 'به پایان محتوای فعلی این کتاب رسیدیم! می‌خواهی از اول مرور کنیم یا سؤال بپرسی؟',
      );
    }
    final questionSentence = BookSectionUtils.pickQuestionSourceSentence(section);
    final question = _toQuestion(questionSentence);
    final body =
        '📖 ${section.heading}\n\n${section.content}\n\n❓ $question';
    return AiEngineResponse(
      body: body,
      sourceReference: '${section.bookTitle} — بخش ${section.index + 1}',
      posedNewQuestion: true,
      newHintSentence: questionSentence,
    );
  }

  AiEngineResponse _giveExample(AiEngineRequest r) {
    final section = r.currentSection;
    if (section == null) {
      return const AiEngineResponse(body: 'برای گرفتن مثال، اول یک درس را شروع کن.');
    }
    final example = BookSectionUtils.pickExampleSentence(section);
    return AiEngineResponse(
      body: '💡 مثال از همین درس:\n$example',
      sourceReference: '${section.bookTitle} — بخش ${section.index + 1}',
    );
  }

  AiEngineResponse _askQuestion(AiEngineRequest r) {
    final section = r.currentSection;
    if (section == null) {
      return const AiEngineResponse(body: 'برای سؤال گرفتن، اول یک درس را شروع کن.');
    }
    final sentence = BookSectionUtils.pickQuestionSourceSentence(section);
    final question = _toQuestion(sentence);
    return AiEngineResponse(
      body: '❓ $question',
      sourceReference: '${section.bookTitle} — بخش ${section.index + 1}',
      posedNewQuestion: true,
      newHintSentence: sentence,
    );
  }

  AiEngineResponse _gradeAnswer(AiEngineRequest r) {
    final hint = r.pendingHintSentence ?? '';
    final overlap = _overlapRatio(r.studentMessage, hint);
    if (overlap >= 0.22) {
      return AiEngineResponse(
        body:
            'آفرین، درست است! 🎉\nطبق متن کتاب: «$hint»\nآمادهٔ درس بعدی هستی یا یک مثال دیگر بخواهی؟',
        sourceReference: r.currentSection != null
            ? '${r.currentSection!.bookTitle} — بخش ${r.currentSection!.index + 1}'
            : null,
        wasCorrectAttempt: true,
      );
    }
    return AiEngineResponse(
      body:
          'نزدیک بود، اما دقیق‌تر این‌طور است:\n«$hint»\nمی‌خواهی دوباره امتحان کنی یا برویم درس بعد؟',
      sourceReference: r.currentSection != null
          ? '${r.currentSection!.bookTitle} — بخش ${r.currentSection!.index + 1}'
          : null,
      wasCorrectAttempt: false,
    );
  }

  AiEngineResponse _answerFreeQuestion(AiEngineRequest r) {
    if (_isOffTopic(r.studentMessage)) {
      return const AiEngineResponse(
        body:
            'این موضوع خارج از این درس است. بیا به موضوع فعلی برگردیم — می‌خواهی تمرین بیشتری روی همین درس کار کنیم؟',
      );
    }
    final matches = BookSectionUtils.findRelevant(r.allSections, r.studentMessage, topN: 1);
    if (matches.isEmpty) {
      return const AiEngineResponse(
        body:
            'این را دقیقاً در کتاب پیدا نکردم. می‌توانی سؤالت را ساده‌تر بپرسی، یا بگو «سؤال بده» تا از همین درس تمرین کنیم.',
      );
    }
    final section = matches.first;
    return AiEngineResponse(
      body: 'بر اساس کتاب:\n${section.content}',
      sourceReference: '${section.bookTitle} — بخش ${section.index + 1}',
    );
  }

  String _toQuestion(String sentence) {
    final trimmed = sentence.replaceAll(RegExp(r'[\.\!\؟۔]+$'), '');
    if (trimmed.length > 90) {
      return 'طبق آنچه خواندیم، دربارهٔ این نکته توضیح بده: «${trimmed.substring(0, 90)}…»؟';
    }
    return 'طبق متن، این جمله را با کلمات خودت توضیح بده: «$trimmed»؟';
  }

  double _overlapRatio(String studentAnswer, String hint) {
    Set<String> tokenize(String t) => t
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.length >= 2)
        .toSet();
    final a = tokenize(studentAnswer);
    final b = tokenize(hint);
    if (a.isEmpty || b.isEmpty) return 0;
    return a.intersection(b).length / b.length;
  }
}
