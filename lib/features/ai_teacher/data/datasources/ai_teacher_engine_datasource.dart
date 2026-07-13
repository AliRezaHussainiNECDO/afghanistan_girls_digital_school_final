import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../curriculum_library/data/datasources/curriculum_library_local_datasource.dart';
import '../../../curriculum_library/domain/entities/curriculum_book.dart';
import '../../../../shared_models/subject.dart';
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
class AiTeacherEngineDataSource {
  final CurriculumLibraryLocalDataSource _library;
  final AiEngine Function() _engineProvider;

  AiTeacherEngineDataSource({
    required CurriculumLibraryLocalDataSource library,
    required AiEngine Function() engineProvider,
  })  : _library = library,
        _engineProvider = engineProvider;

  String _convKey(String subjectId) => 'ai_conversation_v1_$subjectId';
  String _stateKey(String subjectId) => 'ai_state_v1_$subjectId';

  Future<List<AiChatMessage>> _readConversation(String subjectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_convKey(subjectId));
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => _messageFromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _writeConversation(String subjectId, List<AiChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _convKey(subjectId), jsonEncode(messages.map(_messageToJson).toList()));
  }

  Future<_ConversationState> _readState(String subjectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_stateKey(subjectId));
    if (raw == null) return _ConversationState();
    return _ConversationState.fromJson(Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }

  Future<void> _writeState(String subjectId, _ConversationState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_stateKey(subjectId), jsonEncode(state.toJson()));
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

  /// بخش‌های قابل‌تدریس — **مطابق صنف شاگرد**: اگر کتاب صنف او وارد شده
  /// باشد فقط از همان کتاب تدریس می‌شود (طبق نصاب رسمی)؛ در غیر این صورت از
  /// همهٔ کتاب‌های مضمون.
  Future<List<BookSection>> _sectionsFor(String subjectId) async {
    final prefs = await SharedPreferences.getInstance();
    final grade = prefs.getInt('student_grade_v1') ?? 7;
    final books = await _library.getBooksForSubject(subjectId);
    final gradeBooks = books.where((b) => b.gradeId == grade).toList();
    final effective = gradeBooks.isNotEmpty ? gradeBooks : books;
    final sorted = List<CurriculumBook>.from(effective)
      ..sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
    return BookSectionUtils.sectionsForBooks(sorted);
  }

  Future<List<AiChatMessage>> getConversation(String subjectId) async {
    final existing = await _readConversation(subjectId);
    if (existing.isNotEmpty) return existing;
    // اولین بار: پیام خوش‌آمدگویی + شروع خودکار درس.
    final welcome = AiChatMessage(
      id: 'welcome-$subjectId',
      sender: ChatSender.ai,
      body:
          'سلام! 🌸 من معلم هوشمند مضمون «${_subjectNameFa(subjectId)}» هستم و مستقیماً از روی کتاب رسمی نصاب تعلیمی افغانستان با تو کار می‌کنم.',
      timestamp: DateTime.now(),
    );
    await _writeConversation(subjectId, [welcome]);
    await sendMessage(subjectId, AiCommands.start);
    return _readConversation(subjectId);
  }

  Future<AiChatMessage> sendMessage(String subjectId, String text) async {
    final sections = await _sectionsFor(subjectId);
    final state = await _readState(subjectId);
    final history = await _readConversation(subjectId);
    final personaDescription =
        'دقیق و قدم‌به‌قدم، با مثال‌های بومی افغانستان و لحنی گرم و تشویق‌کننده برای دختران دانش‌آموز.';

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
      studentMessage: text,
    ));

    // ── ثبت پیشرفت یادگیری (ذخیرهٔ دروس خوانده/یادگرفته‌شده) ──
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'ai_last_studied_v1_$subjectId', DateTime.now().toIso8601String());
    if (intent == AiIntent.answerAttempt) {
      // شاگرد به سوال معلم پاسخ داد → این بخش «یادگرفته‌شده» حساب می‌شود.
      final mastered = prefs.getInt('ai_mastered_v1_$subjectId') ?? 0;
      await prefs.setInt('ai_mastered_v1_$subjectId', mastered + 1);
    }

    state.awaitingAnswer = response.posedNewQuestion;
    state.hintSentence = response.newHintSentence ?? (response.posedNewQuestion ? state.hintSentence : null);
    await _writeState(subjectId, state);

    final aiMessage = AiChatMessage(
      id: 'm${DateTime.now().millisecondsSinceEpoch + 1}',
      sender: ChatSender.ai,
      body: response.body,
      timestamp: DateTime.now(),
      sourceReference: response.sourceReference,
    );
    updatedHistory.add(aiMessage);
    await _writeConversation(subjectId, updatedHistory);
    return aiMessage;
  }
}
