import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../curriculum_library/data/datasources/curriculum_library_local_datasource.dart';
import '../../../curriculum_library/domain/entities/curriculum_book.dart';
import '../../../../shared_models/subject.dart';
import 'learning_progress_datasource.dart';
import '../../domain/engine/ai_engine.dart';
import '../../domain/engine/book_section_utils.dart';
import '../../domain/entities/chat_message.dart';

/// دستورهای سریع UI — دکمه‌های «درس بعدی»، «مثال دیگر»، «سؤال بده» این
/// مقادیر ثابت را می‌فرستند تا موتور بداند دقیقاً چه کاری باید انجام دهد
/// (به‌جای تشخیص نیت از روی متن آزاد که غیرقابل‌اعتماد است).
class AiCommands {
  AiCommands._();
  static const start = '__cmd_start__';
  static const next = '__cmd_next__';
  static const example = '__cmd_example__';
  static const question = '__cmd_question__';
}

/// شخصیت پیش‌فرض معلم هوشمند — وقتی مدیر هنوز از «مدیریت معلم هوشمند»
/// شخصیتی برای این مضمون تنظیم نکرده باشد.
const String kDefaultAiTeacherPersona =
    'دقیق و قدم‌به‌قدم، با مثال‌های بومی افغانستان و لحنی گرم، صبور و '
    'تشویق‌کننده برای یک دانش‌آموز دختر — همیشه دلگرمی می‌دهد، هرگز سرزنش نمی‌کند.';

class _ConversationState {
  int sectionIndex;
  bool awaitingAnswer;
  String? hintSentence;

  /// «حلقهٔ یادگیری تطبیقی»: مثبت = چند پاسخ درست پیاپی، منفی = چند پاسخ
  /// غلط پیاپی (بین -۳ و +۳). برای تطبیق سطح سختی توضیح در پیام بعدی
  /// استفاده می‌شود.
  int correctStreak;

  _ConversationState({
    this.sectionIndex = 0,
    this.awaitingAnswer = false,
    this.hintSentence,
    this.correctStreak = 0,
  });

  Map<String, dynamic> toJson() => {
        'sectionIndex': sectionIndex,
        'awaitingAnswer': awaitingAnswer,
        'hintSentence': hintSentence,
        'correctStreak': correctStreak,
      };
  factory _ConversationState.fromJson(Map<String, dynamic> j) => _ConversationState(
        sectionIndex: j['sectionIndex'] as int? ?? 0,
        awaitingAnswer: j['awaitingAnswer'] as bool? ?? false,
        hintSentence: j['hintSentence'] as String?,
        correctStreak: j['correctStreak'] as int? ?? 0,
      );

  /// راهنمای متنی تطبیق سختی برای پرامپت سیستم — `null` یعنی روند عادی.
  String? get difficultyHint {
    if (correctStreak <= -2) {
      return 'شاگرد چند بار پیاپی در پاسخ‌ها اشتباه کرده — توضیح را خیلی ساده‌تر، با مثال بیشتر و مرحله‌به‌مرحله بده؛ فعلاً سؤال سخت نپرس، فقط دلگرمی بده.';
    }
    if (correctStreak >= 2) {
      return 'شاگرد چند بار پیاپی سریع و درست پاسخ داده — کمی چالش‌برانگیزتر برو، توضیح را کوتاه‌تر کن و سؤال کمی عمیق‌تر بپرس.';
    }
    return null;
  }

  void registerAttempt(bool wasCorrect) {
    if (wasCorrect) {
      correctStreak = correctStreak < 0 ? 1 : (correctStreak + 1).clamp(0, 3);
    } else {
      correctStreak = correctStreak > 0 ? -1 : (correctStreak - 1).clamp(-3, 0);
    }
  }
}

/// جایگزین واقعی Mock DataSource قدیمی — واقعاً از روی کتاب‌های آپلودشدهٔ
/// مدیر تدریس می‌کند (طبق درخواست صریح کاربر که این بخش «قلب تپندهٔ برنامه»
/// است). گفتگو و وضعیت درس هر شاگرد به‌صورت محلی ذخیره می‌شود تا با
/// بازگشت به برنامه از همان‌جا ادامه یابد.
///
/// **هماهنگی صنف/مضمون:** صنف شاگرد هرگز داخل این کلاس ذخیره نمی‌شود — هر
/// متد `grade` را از بیرون می‌گیرد (منبع واحد حقیقت: `activeGradeProvider`،
/// همان صنفی که در نقشهٔ صنوف/داشبورد/نصاب استفاده می‌شود). به همین دلیل
/// معلم هوشمند همیشه دقیقاً از کتاب همان صنفی که شاگرد الان در آن است
/// تدریس می‌کند، و با ارتقای صنف خودکار به کتاب صنف جدید می‌رود — بدون
/// قاطی‌شدن گفتگو/پیشرفت صنف قبلی با صنف جدید (کلیدهای ذخیره‌سازی به‌ازای
/// هر صنف جدا هستند).
class AiTeacherEngineDataSource {
  final CurriculumLibraryDataSource _library;
  final AiEngine Function() _engineProvider;

  /// شخصیت تنظیم‌شدهٔ مدیر برای یک مضمون (از «مدیریت معلم هوشمند»)؛ `null`
  /// اگر تنظیم نشده — آنگاه [kDefaultAiTeacherPersona] استفاده می‌شود.
  final Future<String?> Function(String subjectId)? _personaLookup;

  /// معماری ۱ — بازیابی معنایی (RAG واقعی) برای سؤال‌های آزاد شاگرد؛ اگر
  /// `null` یا هر خطایی بدهد، به بازیابی کلمه‌ای محلی برمی‌گردیم.
  final Future<List<BookSection>> Function(String subjectId, int grade, String query)?
      _semanticSearch;

  /// معماری ۲ — لاگ سرور برای «درست/غلط بودن» هر پاسخ ارزیابی‌شده (آمار
  /// دقت پنل مدیر + امتیاز مشترک). Fire-and-forget؛ هرگز گفتگو را کند نمی‌کند.
  final Future<void> Function(String subjectId, int grade, bool wasCorrect)? _logAttempt;

  AiTeacherEngineDataSource({
    required CurriculumLibraryDataSource library,
    required AiEngine Function() engineProvider,
    Future<String?> Function(String subjectId)? personaLookup,
    Future<List<BookSection>> Function(String subjectId, int grade, String query)? semanticSearch,
    Future<void> Function(String subjectId, int grade, bool wasCorrect)? logAttempt,
  })  : _library = library,
        _engineProvider = engineProvider,
        _personaLookup = personaLookup,
        _semanticSearch = semanticSearch,
        _logAttempt = logAttempt;

  String _convKey(String subjectId, int grade) =>
      LearningProgressDataSource.conversationKey(subjectId, grade);
  String _stateKey(String subjectId, int grade) =>
      LearningProgressDataSource.stateKey(subjectId, grade);

  Future<List<AiChatMessage>> _readConversation(String subjectId, int grade) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convKey(subjectId, grade));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => _messageFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _writeConversation(
      String subjectId, int grade, List<AiChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _convKey(subjectId, grade), jsonEncode(messages.map(_messageToJson).toList()));
  }

  Future<_ConversationState> _readState(String subjectId, int grade) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey(subjectId, grade));
    if (raw == null) return _ConversationState();
    return _ConversationState.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  Future<void> _writeState(String subjectId, int grade, _ConversationState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey(subjectId, grade), jsonEncode(state.toJson()));
  }

  Map<String, dynamic> _messageToJson(AiChatMessage m) => {
        'id': m.id,
        'sender': m.sender.name,
        'body': m.body,
        'timestamp': m.timestamp.toIso8601String(),
        'sourceReference': m.sourceReference,
      };

  AiChatMessage _messageFromJson(Map<String, dynamic> j) => AiChatMessage(
        id: j['id'] as String,
        sender: (j['sender'] as String) == 'ai' ? ChatSender.ai : ChatSender.student,
        body: j['body'] as String,
        timestamp: DateTime.tryParse(j['timestamp'] as String? ?? '') ?? DateTime.now(),
        sourceReference: j['sourceReference'] as String?,
      );

  String _subjectNameFa(String subjectId) =>
      mockSubjects.firstWhere((s) => s.id == subjectId, orElse: () => mockSubjects.first).nameFa;

  /// بخش‌های قابل‌تدریس — **مطابق صنف واقعی شاگرد**: اگر کتاب صنف او وارد
  /// شده باشد فقط از همان کتاب تدریس می‌شود (طبق نصاب رسمی)؛ در غیر این
  /// صورت از همهٔ کتاب‌های مضمون (تا شاگرد هرگز بدون درس نماند).
  Future<List<BookSection>> _sectionsFor(String subjectId, int grade) async {
    final books = await _library.getBooksForSubject(subjectId);
    final gradeBooks = books.where((b) => b.gradeId == grade).toList();
    final effective = gradeBooks.isNotEmpty ? gradeBooks : books;
    final sorted = List<CurriculumBook>.from(effective)
      ..sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
    return BookSectionUtils.sectionsForBooks(sorted);
  }

  Future<String> _personaFor(String subjectId) async {
    if (_personaLookup == null) return kDefaultAiTeacherPersona;
    try {
      final p = await _personaLookup(subjectId);
      return (p == null || p.trim().isEmpty) ? kDefaultAiTeacherPersona : p.trim();
    } catch (_) {
      return kDefaultAiTeacherPersona;
    }
  }

  /// دستورهای داخلی UI (`__cmd_*__`) هرگز نباید عیناً به موتور هوش مصنوعی
  /// ابری/Ollama فرستاده شوند — آن‌ها فقط متن انسانی می‌فهمند. اینجا هر
  /// دستور را به یک درخواست طبیعی و گرم به زبان دری ترجمه می‌کنیم؛ موتور
  /// محلی رایگان از روی `intent` کار می‌کند و این متن را نادیده می‌گیرد.
  String _naturalInstructionFor(AiIntent intent, String raw) {
    switch (intent) {
      case AiIntent.startLesson:
        return 'سلام معلم! درس این بخش از کتاب را برایم به‌صورت ساده و قدم‌به‌قدم شروع کن.';
      case AiIntent.nextSection:
        return 'این بخش را فهمیدم — لطفاً به بخش بعدی کتاب برو و ادامهٔ درس را بده.';
      case AiIntent.giveExample:
        return 'می‌شود یک مثال واقعی از همین بخش کتاب برایم بزنی تا بهتر بفهمم؟';
      case AiIntent.askQuestion:
        return 'یک سؤال دربارهٔ همین بخش از من بپرس تا ببینیم چقدر یاد گرفته‌ام.';
      case AiIntent.answerAttempt:
      case AiIntent.freeQuestion:
        return raw;
    }
  }

  bool _looksLikeStaleNoBookMessage(AiChatMessage m) =>
      m.sender == ChatSender.ai && m.body.contains('آپلود نشده');

  Future<List<AiChatMessage>> getConversation(String subjectId, int grade) async {
    var existing = await _readConversation(subjectId, grade);

    // رفع اشکال کش قدیمی: اگر آخرین پیام ذخیره‌شده همان «هنوز کتابی آپلود
    // نشده» است (از زمانی که واقعاً کتابی نبود یا معلم هوشمند به‌اشتباه به
    // کتابخانهٔ محلی خالی وصل بود)، و حالا کتاب/فصل واقعاً در دسترس است،
    // این گفتگوی قدیمی را دور می‌ریزیم و از نو شروع می‌کنیم. وگرنه شاگرد
    // برای همیشه با یک پیام اشتباه گیر می‌ماند، حتی مدت‌ها بعد از اینکه
    // مدیر کتاب را آپلود/ساختاربندی کرده.
    if (existing.isNotEmpty && _looksLikeStaleNoBookMessage(existing.last)) {
      final sections = await _sectionsFor(subjectId, grade);
      if (sections.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_convKey(subjectId, grade));
        await prefs.remove(_stateKey(subjectId, grade));
        existing = [];
      }
    }

    if (existing.isNotEmpty) return existing;
    // اولین بار در این صنف: پیام خوش‌آمدگویی + شروع خودکار درس.
    final welcome = AiChatMessage(
      id: 'welcome-$subjectId-g$grade',
      sender: ChatSender.ai,
      body:
          'سلام! 🌸 من معلم هوشمند مضمون «${_subjectNameFa(subjectId)}» صنف $grade هستم و مستقیماً از روی کتاب رسمی نصاب تعلیمی افغانستان با تو کار می‌کنم. آماده‌ای شروع کنیم؟',
      timestamp: DateTime.now(),
    );
    await _writeConversation(subjectId, grade, [welcome]);
    await sendMessage(subjectId, AiCommands.start, grade);
    return _readConversation(subjectId, grade);
  }

  Future<AiChatMessage> sendMessage(String subjectId, String text, int grade) async {
    final sections = await _sectionsFor(subjectId, grade);
    final state = await _readState(subjectId, grade);
    final history = await _readConversation(subjectId, grade);
    final personaDescription = await _personaFor(subjectId);

    AiIntent intent;
    switch (text) {
      case AiCommands.start:
        intent = AiIntent.startLesson;
        break;
      case AiCommands.next:
        intent = AiIntent.nextSection;
        state.sectionIndex += 1;
        break;
      case AiCommands.example:
        intent = AiIntent.giveExample;
        break;
      case AiCommands.question:
        intent = AiIntent.askQuestion;
        break;
      default:
        intent = state.awaitingAnswer ? AiIntent.answerAttempt : AiIntent.freeQuestion;
    }

    var currentSection =
        state.sectionIndex < sections.length ? sections[state.sectionIndex] : null;
    var effectiveSections = sections;

    // ── معماری ۱: برای سؤال آزاد، به‌جای محدود ماندن به «بخش فعلی»، ابتدا
    // بازیابی معنایی سرور را امتحان می‌کن — شاگرد ممکن است دربارهٔ هر جای
    // کتاب بپرسد، نه فقط بخشی که الان روی آن است. اگر نتیجه‌ای نداد (سرور
    // در دسترس نیست/هنوز نمایه نشده)، بی‌صدا به همان رفتار قبلی (بخش فعلی
    // یا بازیابی کلمه‌ای محلی روی کل کتاب) برمی‌گردیم.
    if (intent == AiIntent.freeQuestion && _semanticSearch != null && text.trim().isNotEmpty) {
      try {
        final retrieved = await _semanticSearch(subjectId, grade, text);
        if (retrieved.isNotEmpty) {
          effectiveSections = retrieved;
          currentSection = null; // موتورها روی effectiveSections (از قبل رتبه‌بندی‌شده) کار می‌کنند.
        }
      } catch (_) {
        // بی‌صدا به رفتار قبلی برمی‌گردیم.
      }
    }

    // پیام دانش‌آموز را فقط برای دستورهای واقعی (نه دکمه‌های سیستمی) ثبت می‌کنیم.
    final isSystemCommand = text == AiCommands.start ||
        text == AiCommands.next ||
        text == AiCommands.example ||
        text == AiCommands.question;
    final updatedHistory = List<AiChatMessage>.from(history);
    if (!isSystemCommand) {
      updatedHistory.add(AiChatMessage(
        id: 'm${DateTime.now().millisecondsSinceEpoch}',
        sender: ChatSender.student,
        body: text,
        timestamp: DateTime.now(),
      ));
    }

    final engine = _engineProvider();
    final response = await engine.respond(AiEngineRequest(
      intent: intent,
      subjectId: subjectId,
      subjectNameFa: _subjectNameFa(subjectId),
      personaDescription: personaDescription,
      currentSection: currentSection,
      allSections: effectiveSections,
      pendingHintSentence: state.hintSentence,
      history: updatedHistory,
      // دستورهای داخلی (`__cmd_*__`) هرگز عیناً به موتور فرستاده نمی‌شوند —
      // ترجمهٔ طبیعی و گرم آن‌ها اینجا ساخته می‌شود (رفع اشکال نشتِ دستور).
      studentMessage: _naturalInstructionFor(intent, text),
      // ── معماری ۲: حلقهٔ یادگیری تطبیقی — سطح توضیح را بر اساس چند پاسخ اخیر تنظیم می‌کند.
      difficultyHint: state.difficultyHint,
    ));

    // ── ثبت پیشرفت یادگیری (ذخیرهٔ دروس خوانده/یادگرفته‌شده)، به‌ازای صنف ──
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LearningProgressDataSource.lastStudiedKey(subjectId, grade),
        DateTime.now().toIso8601String());
    if (intent == AiIntent.answerAttempt) {
      // شاگرد به سوال معلم پاسخ داد → این بخش «یادگرفته‌شده» حساب می‌شود.
      final masteredKey = LearningProgressDataSource.masteredKey(subjectId, grade);
      final mastered = prefs.getInt(masteredKey) ?? 0;
      await prefs.setInt(masteredKey, mastered + 1);

      // ── معماری ۲: سیگنال درست/غلط از موتور → تطبیق سختی + لاگ سرور برای
      // آمار دقت و امتیاز مشترک. کاملاً Fire-and-forget؛ منتظرش نمی‌مانیم
      // تا نمایش پاسخ به شاگرد کند نشود.
      final wasCorrect = response.wasCorrectAttempt;
      if (wasCorrect != null) {
        state.registerAttempt(wasCorrect);
        if (_logAttempt != null) {
          unawaited(_logAttempt(subjectId, grade, wasCorrect).catchError((_) {}));
        }
      }
    }

    state.awaitingAnswer = response.posedNewQuestion;
    state.hintSentence = response.newHintSentence ?? (response.posedNewQuestion ? state.hintSentence : null);
    await _writeState(subjectId, grade, state);

    final aiMessage = AiChatMessage(
      id: 'm${DateTime.now().millisecondsSinceEpoch + 1}',
      sender: ChatSender.ai,
      body: response.body,
      timestamp: DateTime.now(),
      sourceReference: response.sourceReference,
    );
    updatedHistory.add(aiMessage);
    await _writeConversation(subjectId, grade, updatedHistory);
    return aiMessage;
  }

  // ═════════════ حالت «تمرکز روی یک درس مشخص» ═════════════════════════════
  // طبق درخواست کاربر: وقتی «پرسش از معلم» از داخل صفحهٔ یک درس باز می‌شود
  // (نه از فهرست کلی مضمون)، معلم هوشمند باید دقیقاً همان درس را تدریس کند،
  // از شاگرد دربارهٔ آن سؤال بپرسد و پاسخش را ارزیابی کند — نه کل کتاب یا
  // مضمون. چون محتوای درس مستقیماً از همان صفحه‌ای می‌آید که شاگرد در حال
  // دیدنش است (نه از کتابخانهٔ نصاب/کش محلی)، این مسیر هرگز به مشکل «کتابی
  // آپلود نشده» برنمی‌خورد و برای هر مضمون و هر صنفی دقیقاً یکسان کار
  // می‌کند. گفتگو و پیشرفت هر درس جدا از گفتگوی کلی مضمون ذخیره می‌شود تا
  // با رفتن سراغ درس دیگر، تاریخچهٔ درس قبلی گیج‌کننده نماند.

  String _lessonConvKey(String lessonId) => 'ai_lesson_conv_v1_$lessonId';
  String _lessonStateKey(String lessonId) => 'ai_lesson_state_v1_$lessonId';

  /// محتوای درس را به چند «بخش» ~۶ جمله‌ای (همان واحد تدریس بقیهٔ موتور)
  /// تقسیم می‌کند تا دستورهای «بخش بعدی»/«مثال دیگر»/«سؤال بده» داخل همین
  /// درس هم به‌طور طبیعی کار کنند؛ اگر متن خیلی کوتاه بود، کل درس یک بخش می‌شود.
  List<BookSection> _sectionsForLessonContent(String lessonId, String lessonTitle, String content) {
    final sentences = BookSectionUtils.splitSentences(content);
    if (sentences.isEmpty) {
      return [
        BookSection(bookId: lessonId, bookTitle: lessonTitle, index: 0, heading: lessonTitle, content: content),
      ];
    }
    final sections = <BookSection>[];
    for (var i = 0; i < sentences.length; i += BookSectionUtils.sentencesPerSection) {
      final chunk = sentences.skip(i).take(BookSectionUtils.sentencesPerSection).toList();
      sections.add(BookSection(
        bookId: lessonId,
        bookTitle: lessonTitle,
        index: sections.length,
        heading: lessonTitle,
        content: chunk.join(' '),
      ));
    }
    return sections;
  }

  Future<List<AiChatMessage>> getLessonConversation({
    required String lessonId,
    required String lessonTitle,
    required String lessonContent,
    required String subjectId,
    required int grade,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lessonConvKey(lessonId));
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      final existing =
          list.map((e) => _messageFromJson(Map<String, dynamic>.from(e as Map))).toList();
      if (existing.isNotEmpty) return existing;
    }
    final welcome = AiChatMessage(
      id: 'welcome-lesson-$lessonId',
      sender: ChatSender.ai,
      body: 'سلام! 🌸 من معلم هوشمند «$lessonTitle» هستم و می‌خواهم دقیقاً همین درس را با تو مرور کنم. آماده‌ای شروع کنیم؟',
      timestamp: DateTime.now(),
    );
    await prefs.setString(
        _lessonConvKey(lessonId), jsonEncode([welcome].map(_messageToJson).toList()));
    await sendLessonMessage(
      lessonId: lessonId,
      lessonTitle: lessonTitle,
      lessonContent: lessonContent,
      subjectId: subjectId,
      grade: grade,
      text: AiCommands.start,
    );
    final rawAfter = prefs.getString(_lessonConvKey(lessonId));
    if (rawAfter == null) return [welcome];
    final list = jsonDecode(rawAfter) as List;
    return list.map((e) => _messageFromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<AiChatMessage> sendLessonMessage({
    required String lessonId,
    required String lessonTitle,
    required String lessonContent,
    required String subjectId,
    required int grade,
    required String text,
  }) async {
    final sections = _sectionsForLessonContent(lessonId, lessonTitle, lessonContent);
    final prefs = await SharedPreferences.getInstance();

    final rawState = prefs.getString(_lessonStateKey(lessonId));
    final state = rawState == null
        ? _ConversationState()
        : _ConversationState.fromJson(Map<String, dynamic>.from(jsonDecode(rawState) as Map));

    final rawConv = prefs.getString(_lessonConvKey(lessonId));
    final history = rawConv == null
        ? <AiChatMessage>[]
        : (jsonDecode(rawConv) as List)
            .map((e) => _messageFromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

    final personaDescription = await _personaFor(subjectId);

    AiIntent intent;
    switch (text) {
      case AiCommands.start:
        intent = AiIntent.startLesson;
        break;
      case AiCommands.next:
        intent = AiIntent.nextSection;
        state.sectionIndex += 1;
        break;
      case AiCommands.example:
        intent = AiIntent.giveExample;
        break;
      case AiCommands.question:
        intent = AiIntent.askQuestion;
        break;
      default:
        intent = state.awaitingAnswer ? AiIntent.answerAttempt : AiIntent.freeQuestion;
    }

    final currentSection =
        state.sectionIndex < sections.length ? sections[state.sectionIndex] : sections.last;

    final isSystemCommand = text == AiCommands.start ||
        text == AiCommands.next ||
        text == AiCommands.example ||
        text == AiCommands.question;
    final updatedHistory = List<AiChatMessage>.from(history);
    if (!isSystemCommand) {
      updatedHistory.add(AiChatMessage(
        id: 'm${DateTime.now().millisecondsSinceEpoch}',
        sender: ChatSender.student,
        body: text,
        timestamp: DateTime.now(),
      ));
    }

    final engine = _engineProvider();
    final response = await engine.respond(AiEngineRequest(
      intent: intent,
      subjectId: subjectId,
      subjectNameFa: _subjectNameFa(subjectId),
      personaDescription: personaDescription,
      currentSection: currentSection,
      allSections: sections,
      pendingHintSentence: state.hintSentence,
      history: updatedHistory,
      studentMessage: _naturalInstructionFor(intent, text),
      difficultyHint: state.difficultyHint,
    ));

    if (intent == AiIntent.answerAttempt) {
      final wasCorrect = response.wasCorrectAttempt;
      if (wasCorrect != null) {
        state.registerAttempt(wasCorrect);
        if (_logAttempt != null) {
          unawaited(_logAttempt(subjectId, grade, wasCorrect).catchError((_) {}));
        }
      }
    }

    state.awaitingAnswer = response.posedNewQuestion;
    state.hintSentence =
        response.newHintSentence ?? (response.posedNewQuestion ? state.hintSentence : null);
    await prefs.setString(_lessonStateKey(lessonId), jsonEncode(state.toJson()));

    final aiMessage = AiChatMessage(
      id: 'm${DateTime.now().millisecondsSinceEpoch + 1}',
      sender: ChatSender.ai,
      body: response.body,
      timestamp: DateTime.now(),
      sourceReference: response.sourceReference,
    );
    updatedHistory.add(aiMessage);
    await prefs.setString(
        _lessonConvKey(lessonId), jsonEncode(updatedHistory.map(_messageToJson).toList()));
    return aiMessage;
  }
}
