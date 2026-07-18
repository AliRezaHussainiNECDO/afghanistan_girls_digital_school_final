import '../../../core/localization/translations/en.dart';
import '../../../core/localization/translations/fa.dart';
import '../../../core/localization/translations/fr.dart';
import '../../../core/localization/translations/ps.dart';
import '../../ai_teacher/domain/engine/ai_engine.dart';
import '../../ai_teacher/domain/entities/chat_message.dart';
import '../../curriculum_library/domain/entities/curriculum_book.dart';
import '../domain/advisor_entities.dart';

/// خروجی یک پاسخ مشاور.
class AdvisorReply {
  final String text;
  final bool flagged; // نشانهٔ نگرانی — نیاز به توجه مدیر
  final String topic;
  const AdvisorReply({required this.text, this.flagged = false, this.topic = 'general'});
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
///
/// [localeCode] زبان فعال اپ (fa/ps/en/fr) است — همهٔ پاسخ‌های درون‌ساخت و
/// دستورالعمل زبان به موتور هوش مصنوعی طبق همین زبان انتخاب می‌شوند تا
/// شاگرد همیشه به زبانی که خودش انتخاب کرده پاسخ بگیرد.
class AdvisorService {
  final AiEngine engine;
  final String localeCode;
  AdvisorService(this.engine, {this.localeCode = 'fa'});

  Map<String, String> get _strings => switch (localeCode) {
        'ps' => psStrings,
        'en' => enStrings,
        'fr' => frStrings,
        _ => faStrings,
      };

  String _t(String key) => _strings[key] ?? key;

  Future<AdvisorReply> reply({
    required List<AdvisorMessage> history,
    required String userText,
  }) async {
    final text = userText.trim();
    if (text.isEmpty) {
      return AdvisorReply(text: _t('advisorService.emptyTextReply'));
    }

    // ۱) لایهٔ ایمنی — پیش از هر چیز. کلمات نگران‌کننده در هر ۴ زبان بررسی
    // می‌شوند (نه فقط زبان فعال اپ) چون پیام شاگرد ممکن است به زبان دیگری
    // نوشته شده باشد.
    if (_isConcerning(text)) {
      return AdvisorReply(text: _t('advisorService.supportiveSafeReply'), flagged: true, topic: 'sensitive');
    }

    final topic = _detectTopic(text);

    // ۲) تلاش برای پاسخ با موتور واقعی.
    try {
      final recent = history.length > 6 ? history.sublist(history.length - 6) : history;
      final roleStudent = _t('advisorService.roleStudent');
      final roleAdvisor = _t('advisorService.roleAdvisor');
      final ctx = recent
          .map((m) => '${m.role == AdvisorRole.student ? roleStudent : roleAdvisor}: ${m.text}')
          .join('\n');
      final priorLabel = _t('advisorService.priorConversationLabel');
      final freshLabel = _t('advisorService.freshMessageLabel');
      final prompt = '''
${ctx.isEmpty ? '' : '$priorLabel\n$ctx\n\n'}$freshLabel $text

${_t('advisorService.languageInstruction')}''';

      final res = await engine.respond(AiEngineRequest(
        intent: AiIntent.freeQuestion,
        subjectId: 'advisor',
        subjectNameFa: _t('advisorService.subjectName'),
        personaDescription: _t('advisorService.personaDescription'),
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
  // کلمات نگران‌کننده به هر ۴ زبان — این‌ها داده‌های تشخیص الگو هستند (نه
  // متن نمایشی)، پس به‌عمد در فایل‌های ترجمه نیستند و همیشه هر ۴ فهرست با
  // هم بررسی می‌شوند تا صرف‌نظر از زبان تایپ شاگرد، لایهٔ ایمنی کار کند.
  static const List<String> _concernWordsFa = [
    'خودکشی', 'خودم را بکشم', 'خودمو بکشم', 'نمیخواهم زنده', 'نمی‌خواهم زنده',
    'به زندگی ادامه', 'تمامش کنم', 'بمیرم', 'مرگ', 'آسیب به خودم', 'خودآزاری',
    'کتک', 'آزار', 'اذیت جنسی', 'تجاوز', 'فرار از خانه', 'ازدواج اجباری',
    'دیگر امیدی', 'هیچ‌کس دوستم ندارد', 'هیچ کس دوستم ندارد',
  ];
  static const List<String> _concernWordsPs = [
    'ځان وژنه', 'ځان ووژنم', 'ژوند نه غواړم', 'مړه شم', 'ځان ته زیان',
    'ځان ځورونه', 'وهل', 'ځورونه', 'جنسي ځورونه', 'تجاوز', 'له کوره تښتیدل',
    'جبري واده', 'امید نشته', 'هیڅوک ما سره مینه نلري',
  ];
  static const List<String> _concernWordsEn = [
    'suicide', 'kill myself', "don't want to live", 'want to die', 'end it all',
    'end my life', 'hurt myself', 'self harm', 'self-harm', 'beaten', 'abuse',
    'sexual abuse', 'rape', 'run away from home', 'forced marriage', 'no hope',
    'nobody loves me', 'no one loves me',
  ];
  static const List<String> _concernWordsFr = [
    'suicide', 'me suicider', 'me tuer', 'je ne veux plus vivre', 'en finir',
    'me faire du mal', 'automutilation', 'battue', 'maltraitance', 'abus sexuel',
    'viol', 'fuguer', 'mariage forcé', "plus d'espoir", "personne ne m'aime",
  ];

  bool _isConcerning(String text) {
    final t = text.toLowerCase().replaceAll('‌', '');
    final all = [..._concernWordsFa, ..._concernWordsPs, ..._concernWordsEn, ..._concernWordsFr];
    return all.any((w) => t.contains(w.toLowerCase().replaceAll('‌', '')));
  }

  // ─────────────────── تشخیص موضوع ───────────────────
  static const Map<String, List<String>> _topicWords = {
    'psychological': [
      'استرس', 'اضطراب', 'غمگین', 'ناراحت', 'افسرده', 'تنها', 'خسته', 'ترس',
      'ربړ', 'اندېښنه', 'خپه', 'ستړی',
      'stress', 'anxiety', 'sad', 'depressed', 'lonely', 'tired', 'afraid',
      'stressé', 'anxieux', 'triste', 'déprimée', 'seule', 'fatiguée', 'peur',
    ],
    'family': [
      'خانواده', 'مادر', 'پدر', 'خواهر', 'برادر', 'خانه',
      'کورنۍ', 'مور', 'پلار', 'خور', 'ورور', 'کور',
      'family', 'mother', 'father', 'sister', 'brother', 'home',
      'famille', 'mère', 'père', 'sœur', 'frère', 'maison',
    ],
    'social': [
      'دوست', 'همصنفی', 'هم‌صنفی', 'مکتب', 'معلم', 'دعوا',
      'ملګری', 'ښوونځی', 'ښوونکی', 'شخړه',
      'friend', 'classmate', 'school', 'teacher', 'fight',
      'ami', 'amie', 'camarade', 'école', 'enseignant', 'dispute',
    ],
    'academic': [
      'درس', 'امتحان', 'نمره', 'مضمون', 'تمرکز', 'مطالعه',
      'لوست', 'ازموینه', 'نمره', 'مضمون', 'تمرکز',
      'study', 'exam', 'grade', 'subject', 'focus', 'homework',
      'étude', 'examen', 'note', 'matière', 'concentration', 'devoirs',
    ],
  };

  String _detectTopic(String text) {
    final t = text.toLowerCase();
    for (final entry in _topicWords.entries) {
      if (entry.value.any((w) => t.contains(w.toLowerCase()))) return entry.key;
    }
    return 'daily';
  }

  String _fallbackFor(String topic) {
    switch (topic) {
      case 'psychological':
        return _t('advisorService.fallbackPsychological');
      case 'family':
        return _t('advisorService.fallbackFamily');
      case 'social':
        return _t('advisorService.fallbackSocial');
      case 'academic':
        return _t('advisorService.fallbackAcademic');
      default:
        return _t('advisorService.fallbackDaily');
    }
  }
}
