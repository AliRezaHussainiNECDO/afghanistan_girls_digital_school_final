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
  _ConversationState({this.sectionIndex = 0, this.awaitingAnswer = false, this.hintSentence});

  Map<String, dynamic> toJson() =>
      {'sectionIndex': sectionIndex, 'awaitingAnswer': awaitingAnswer, 'hintSentence': hintSentence};
  factory _ConversationState.fromJson(Map<String, dynamic> j) => _ConversationState(
        sectionIndex: j['sectionIndex'] as int? ?? 0,
        awaitingAnswer: j['awaitingAnswer'] as bool? ?? false,
        hintSentence: j['hintSentence'] as String?,
      );
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
  final CurriculumLibraryLocalDataSource _library;
  final AiEngine Function() _engineProvider;

  /// شخصیت تنظیم‌شدهٔ مدیر برای یک مضمون (از «مدیریت معلم هوشمند»)؛ `null`
  /// اگر تنظیم نشده — آنگاه [kDefaultAiTeacherPersona] استفاده می‌شود.
  final Future<String?> Function(String subjectId)? _personaLookup;

  AiTeacherEngineDataSource({
    required CurriculumLibraryLocalDataSource library,
    required AiEngine Function() engineProvider,
    Future<String?> Function(String subjectId)? personaLookup,
  })  : _library = library,
        _engineProvider = engineProvider,
        _personaLookup = personaLookup;

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

  Future<List<AiChatMessage>> getConversation(String subjectId, int grade) async {
    final existing = await _readConversation(subjectId, grade);
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

    final currentSection =
        state.sectionIndex < sections.length ? sections[state.sectionIndex] : null;

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
      subjectNameFa: _subjectNameFa(subjectId),
      personaDescription: personaDescription,
      currentSection: currentSection,
      allSections: sections,
      pendingHintSentence: state.hintSentence,
      history: updatedHistory,
      // دستورهای داخلی (`__cmd_*__`) هرگز عیناً به موتور فرستاده نمی‌شوند —
      // ترجمهٔ طبیعی و گرم آن‌ها اینجا ساخته می‌شود (رفع اشکال نشتِ دستور).
      studentMessage: _naturalInstructionFor(intent, text),
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
}
