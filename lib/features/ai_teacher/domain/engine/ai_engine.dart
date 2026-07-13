import '../entities/chat_message.dart';
import '../../../curriculum_library/domain/entities/curriculum_book.dart';

enum AiIntent {
  startLesson,
  nextSection,
  giveExample,
  askQuestion,
  answerAttempt,
  freeQuestion,
}

/// درخواست یکپارچه به «موتور معلم هوشمند» — طراحی‌شده تا هم موتور محلی
/// مبتنی‌بر متن کتاب (LocalCurriculumAiEngine) و هم موتور هوش مصنوعی واقعی
/// نصب‌شده روی کامپیوتر کاربر (OllamaAiEngine) بتوانند از یک قرارداد واحد
/// پیروی کنند و در هر لحظه قابل جابه‌جایی باشند.
class AiEngineRequest {
  final AiIntent intent;
  final String subjectNameFa;
  final String personaDescription;
  final BookSection? currentSection;
  final List<BookSection> allSections;
  final String? pendingHintSentence;
  final List<AiChatMessage> history;
  final String studentMessage;

  /// حالت گفتگوی آزاد (مثل «مشاور هوشمند») — پاسخ فقط بر اساس شخصیت
  /// (personaDescription) داده می‌شود، بدون هیچ وابستگی یا ارجاعی به کتاب
  /// نصاب. موتورها در این حالت نباید دربارهٔ «کتاب» حرف بزنند.
  final bool openDomain;

  const AiEngineRequest({
    required this.intent,
    required this.subjectNameFa,
    required this.personaDescription,
    required this.currentSection,
    required this.allSections,
    this.pendingHintSentence,
    required this.history,
    required this.studentMessage,
    this.openDomain = false,
  });
}

class AiEngineResponse {
  final String body;
  final String? sourceReference;

  /// اگر true باشد، یعنی این پاسخ یک سؤال تازه از شاگرد پرسیده و باید
  /// منتظر پاسخ او بمانیم (وضعیت awaitingAnswer در DataSource ذخیره می‌شود).
  final bool posedNewQuestion;
  final String? newHintSentence;

  const AiEngineResponse({
    required this.body,
    this.sourceReference,
    this.posedNewQuestion = false,
    this.newHintSentence,
  });
}

/// قرارداد مشترک موتور معلم هوشمند — طبق درخواست کاربر برای معماری قابل
/// جایگزینی بین «موتور محلی رایگان» و «هوش مصنوعی واقعی نصب‌شده».
abstract class AiEngine {
  String get id;
  Future<AiEngineResponse> respond(AiEngineRequest request);
}
