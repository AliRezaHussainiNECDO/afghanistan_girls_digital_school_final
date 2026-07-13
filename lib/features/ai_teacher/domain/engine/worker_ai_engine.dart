import '../../../../core/network/api_client.dart';
import '../../../curriculum_library/domain/entities/curriculum_book.dart';
import 'ai_engine.dart';
import 'book_section_utils.dart';

/// خطای در دسترس نبودن موتور ابری — تا FallbackAiEngine بی‌صدا به موتور
/// محلی برگردد (اصل Fail-safe بخش ۲۱.۴ سند).
class WorkerAiUnavailableException implements Exception {
  final String message;
  WorkerAiUnavailableException(this.message);
  @override
  String toString() => message;
}

/// موتور معلم هوشمند ابری — به Endpoint امن Worker (`/api/v1/ai-teacher/chat`)
/// وصل می‌شود که خودش به یک ارائه‌دهندهٔ LLM (OpenAI/Claude/سازگار) پروکسی
/// می‌کند. کلید API **هرگز** در اپ نیست؛ فقط روی سرور به‌صورت Secret
/// نگه‌داری می‌شود (بخش ۵.۱: Backend همیشه واسط است).
///
/// Retrieval (بازیابی متن نصاب) همچنان **محلی** انجام می‌شود — همان بخش‌های
/// کتاب که موتور Ollama استفاده می‌کند — تا context دقیقاً مطابق نصاب باشد
/// (بخش ۵.۳.۲). Worker فقط system+messages را به LLM می‌فرستد.
class WorkerAiEngine implements AiEngine {
  final ApiClient _api;
  WorkerAiEngine(this._api);

  @override
  String get id => 'worker-llm';

  @override
  Future<AiEngineResponse> respond(AiEngineRequest r) async {
    final contextSections = r.openDomain
        ? const <BookSection>[]
        : (r.currentSection != null
            ? [r.currentSection!]
            : BookSectionUtils.findRelevant(r.allSections, r.studentMessage, topN: 3));
    final contextText =
        contextSections.map((s) => '[${s.heading}]\n${s.content}').join('\n\n');

    // حالت گفتگوی آزاد (مشاور هوشمند): فقط شخصیت — بدون هیچ قید یا ارجاعی به کتاب.
    final systemPrompt = r.openDomain
        ? '''
تو «${r.subjectNameFa}» در یک مکتب دیجیتال برای دختران افغان هستی.
شخصیت تو: ${r.personaDescription}
به هر پیام شاگرد با دانش عمومی خودت پاسخ بده؛ به هیچ کتاب یا مرجعی نیاز نداری و هرگز دربارهٔ کتاب، مرجع یا آپلود چیزی نگو.
همیشه به زبان دری (فارسی)، با لحنی گرم، کوتاه، همدلانه و امیدبخش پاسخ بده.
'''
        : '''
تو «معلم هوشمند» مضمون «${r.subjectNameFa}» در یک مکتب دیجیتال برای دختران افغان هستی.
شخصیت تو: ${r.personaDescription}
فقط بر اساس متن زیر از کتاب درسی رسمی نصاب تعلیمی افغانستان تدریس کن، سؤال بپرس و مثال بده. اگر پاسخ در متن نیست، صادقانه بگو که در این بخش از کتاب موجود نیست و شاگرد را به موضوع درس برگردان.
همیشه به زبان دری (فارسی)، با لحنی گرم، ساده و تشویق‌کننده برای یک دانش‌آموز دختر پاسخ بده.

متن کتاب:
$contextText
''';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...r.history.take(10).map((m) => {
            'role': m.sender.name == 'ai' ? 'assistant' : 'user',
            'content': m.body,
          }),
      {'role': 'user', 'content': r.studentMessage},
    ];

    try {
      final data = await _api.post('/ai-teacher/chat', data: {'messages': messages});
      final reply = (data is Map ? data['reply'] as String? : null)?.trim();
      if (reply == null || reply.isEmpty) {
        throw WorkerAiUnavailableException('پاسخ خالی از سرور دریافت شد.');
      }
      return AiEngineResponse(
        body: reply,
        sourceReference: contextSections.isNotEmpty
            ? '${contextSections.first.bookTitle} — بخش ${contextSections.first.index + 1}'
            : null,
        posedNewQuestion: reply.contains('؟') || reply.contains('?'),
      );
    } on ApiException catch (e) {
      // به FallbackAiEngine سیگنال بده تا به موتور محلی برگردد.
      throw WorkerAiUnavailableException('اتصال به سرور معلم هوشمند ناموفق بود: ${e.message}');
    }
  }
}
