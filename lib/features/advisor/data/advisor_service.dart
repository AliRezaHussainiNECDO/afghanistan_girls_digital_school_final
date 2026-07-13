import '../../ai_teacher/domain/engine/ai_engine.dart';
import '../../ai_teacher/domain/entities/chat_message.dart';
import '../../curriculum_library/domain/entities/curriculum_book.dart';
import '../domain/advisor_entities.dart';

/// خروجی یک پاسخ مشاور.
class AdvisorReply {
  final String text;
  final bool flagged; // نشانهٔ نگرانی — نیاز به توجه مدیر
  final String topic;
  const AdvisorReply({required this.text, this.flagged = false, this.topic = 'عمومی'});
}

/// سرویس «مشاور هوشمند» — یک مشاور دلسوز و محترم برای دختران افغانستان که
/// در مسائل روانی، اجتماعی، خانوادگی، تحصیلی و روزمره با همدلی راهنمایی
/// می‌کند.
///
/// از موتور واقعی [AiEngine] (Ollama با fallback محلی) استفاده می‌کند؛ اما
/// یک **لایهٔ ایمنی** پیش از موتور قرار دارد: اگر پیام نشانهٔ پریشانی جدی
/// یا آسیب داشته باشد، به‌جای مدل، یک پاسخ حمایتی و امن داده می‌شود و پیام
/// برای بازبینی مدیر «flag» می‌گردد. اگر موتور در دسترس نبود، پاسخ‌های
/// همدلانهٔ درون‌ساخت داده می‌شود تا این بخش هیچ‌وقت بی‌پاسخ نماند.
class AdvisorService {
  final AiEngine engine;
  AdvisorService(this.engine);

  static const String _persona =
      'یک مشاور زن، مهربان، صبور و محترم برای دختران نوجوان افغان. با لحن گرم، '
      'امیدبخش و بدون قضاوت صحبت می‌کند؛ احساسات را به رسمیت می‌شناسد، راهکارهای '
      'عملی و کوچک و سالم پیشنهاد می‌دهد، به فرهنگ و شرایط افغانستان حساس است، و '
      'دختر را به گفت‌وگو با بزرگ‌سالان مورد اعتماد تشویق می‌کند. هرگز توصیهٔ '
      'پزشکی/دارویی قطعی نمی‌دهد و محتوای نامناسب تولید نمی‌کند.';

  Future<AdvisorReply> reply({
    required List<AdvisorMessage> history,
    required String userText,
  }) async {
    final text = userText.trim();
    if (text.isEmpty) {
      return const AdvisorReply(text: 'هر وقت آماده بودی، من اینجا هستم که به حرف‌هایت گوش بدهم. 🌸');
    }

    // ۱) لایهٔ ایمنی — پیش از هر چیز.
    if (_isConcerning(text)) {
      return AdvisorReply(text: _supportiveSafeReply, flagged: true, topic: 'حساس');
    }

    final topic = _detectTopic(text);

    // ۲) تلاش برای پاسخ با موتور واقعی.
    try {
      final recent = history.length > 6 ? history.sublist(history.length - 6) : history;
      final ctx = recent
          .map((m) => '${m.role == AdvisorRole.student ? 'دختر' : 'مشاور'}: ${m.text}')
          .join('\n');
      final prompt = '''
${ctx.isEmpty ? '' : 'خلاصهٔ گفتگوی قبلی:\n$ctx\n\n'}پیام تازهٔ دختر: $text

به‌عنوان مشاور دلسوز، با همدلی و به زبان دری پاسخ بده. کوتاه، گرم و امیدبخش باشد و در صورت مناسب یک راهکار عملی کوچک پیشنهاد بده.''';

      final res = await engine.respond(AiEngineRequest(
        intent: AiIntent.freeQuestion,
        subjectNameFa: 'مشاور دلسوز',
        personaDescription: _persona,
        currentSection: null,
        allSections: const <BookSection>[],
        history: const <AiChatMessage>[],
        studentMessage: prompt,
        // گفتگوی آزاد: مشاور به هیچ کتاب یا مرجعی نیاز ندارد و باید به هر
        // پیام شاگرد پاسخ بدهد (بدون پیام «کتاب آپلود نشده»).
        openDomain: true,
      ));
      final body = res.body.trim();
      if (body.length > 4) {
        return AdvisorReply(text: body, topic: topic);
      }
    } catch (_) {
      // به پاسخ درون‌ساخت می‌رویم.
    }

    // ۳) پاسخ همدلانهٔ درون‌ساخت.
    return AdvisorReply(text: _fallbackFor(topic), topic: topic);
  }

  // ─────────────────── ایمنی ───────────────────
  static const List<String> _concernWords = [
    'خودکشی', 'خودم را بکشم', 'خودمو بکشم', 'نمیخواهم زنده', 'نمی‌خواهم زنده',
    'به زندگی ادامه', 'تمامش کنم', 'بمیرم', 'مرگ', 'آسیب به خودم', 'خودآزاری',
    'کتک', 'آزار', 'اذیت جنسی', 'تجاوز', 'فرار از خانه', 'ازدواج اجباری',
    'دیگر امیدی', 'هیچ‌کس دوستم ندارد', 'هیچ کس دوستم ندارد',
  ];

  bool _isConcerning(String text) {
    final t = text.replaceAll('‌', '');
    return _concernWords.any((w) => t.contains(w.replaceAll('‌', '')));
  }

  static const String _supportiveSafeReply =
      'خیلی متأسفم که این‌قدر سختی می‌کشی 💙 احساس تو مهم است و تو تنها نیستی. '
      'آن‌چه حس می‌کنی واقعی است، اما این درد همیشگی نیست و کمک وجود دارد. '
      'لطفاً همین امروز با یک بزرگ‌سال مورد اعتماد صحبت کن — یک معلم، مادر، خواهر، '
      'یا یکی از مدیران مکتب. مدیریت مکتب می‌تواند تو را به کسی که واقعاً کمک کند '
      'وصل کند. من هم همیشه اینجا هستم تا به حرف‌هایت گوش بدهم. الان دوست داری '
      'دربارهٔ چه چیزی با هم صحبت کنیم؟';

  // ─────────────────── تشخیص موضوع ───────────────────
  String _detectTopic(String text) {
    final t = text;
    if (_any(t, ['استرس', 'اضطراب', 'غمگین', 'ناراحت', 'افسرده', 'تنها', 'خسته', 'ترس'])) {
      return 'روانی';
    }
    if (_any(t, ['خانواده', 'مادر', 'پدر', 'خواهر', 'برادر', 'خانه'])) return 'خانوادگی';
    if (_any(t, ['دوست', 'همصنفی', 'هم‌صنفی', 'مکتب', 'معلم', 'دعوا'])) return 'اجتماعی';
    if (_any(t, ['درس', 'امتحان', 'نمره', 'مضمون', 'تمرکز', 'مطالعه'])) return 'تحصیلی';
    return 'روزمره';
  }

  bool _any(String t, List<String> words) => words.any(t.contains);

  String _fallbackFor(String topic) {
    switch (topic) {
      case 'روانی':
        return 'حس تو کاملاً قابل‌درک است و خوب کردی که دربارهٔ آن حرف زدی 🌸 '
            'یک تمرین کوچک: سه نفس عمیق بکش و به سه چیزی که بابتشان سپاس‌گزاری فکر کن. '
            'دوست داری بیشتر برایم بگویی چه چیزی بیشتر اذیتت می‌کند؟';
      case 'خانوادگی':
        return 'می‌فهمم که مسائل خانوادگی می‌تواند دل آدم را سنگین کند. تو ارزشمندی و '
            'تلاشت دیده می‌شود. اگر بخواهی، می‌توانیم با هم فکر کنیم چطور آرام و محترمانه '
            'احساست را با خانواده در میان بگذاری.';
      case 'اجتماعی':
        return 'روابط با دوستان و مکتب گاهی سخت می‌شود، و این طبیعی است. تو لایق احترام '
            'و دوستی خوب هستی. بگو دقیقاً چه اتفاقی افتاده تا با هم بهترین راه را پیدا کنیم.';
      case 'تحصیلی':
        return 'برای درس و تمرکز راه‌های خوبی هست 💪 یک روش ساده: ۲۵ دقیقه درس، ۵ دقیقه '
            'استراحت. با کوچک شروع کن و به خودت سخت نگیر. کدام مضمون برایت سخت‌تر است؟';
      default:
        return 'ممنون که با من در میان گذاشتی 🌸 من اینجا هستم تا کنارت باشم. کمی بیشتر '
            'برایم بگو تا بهتر بتوانم کمکت کنم.';
    }
  }
}
