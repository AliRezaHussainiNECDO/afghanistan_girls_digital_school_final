import 'package:dio/dio.dart';
import '../../../curriculum_library/domain/entities/curriculum_book.dart';
import 'ai_engine.dart';
import 'ai_prompt_adaptation.dart';
import 'book_section_utils.dart';

/// موتور هوش مصنوعی واقعی — به یک سرور Ollama که **روی کامپیوتر خود کاربر
/// نصب شده** وصل می‌شود (طبق انتخاب کاربر: «یک زبان هوش مصنوعی را در
/// کمپیوترم نصب کنید»، بدون کلید API و بدون هزینهٔ ابری).
///
/// نحوهٔ فعال‌سازی (چون امکان تایپ در ترمینال واقعی کاربر برای من وجود
/// ندارد، این ۳ قدم را خود کاربر انجام می‌دهد):
///   ۱) نصب Ollama از https://ollama.com/download
///   ۲) در ترمینال: `ollama pull llama3.1` (یا هر مدل دیگر)
///   ۳) در همین برنامه، بخش «مدیریت معلم هوشمند» → «موتور هوش مصنوعی» را
///      روشن کنید. آدرس پیش‌فرض http://localhost:11434 است.
///
/// اگر سرور Ollama در دسترس نباشد، این کلاس [OllamaUnavailableException]
/// می‌اندازد و لایهٔ بالاتر به‌صورت خودکار به [LocalCurriculumAiEngine]
/// برمی‌گردد — یعنی اپ هرگز به‌خاطر نبود Ollama از کار نمی‌افتد.
class OllamaUnavailableException implements Exception {
  final String message;
  OllamaUnavailableException(this.message);
  @override
  String toString() => message;
}

class OllamaAiEngine implements AiEngine {
  final String baseUrl;
  final String model;
  final Dio _dio;

  OllamaAiEngine({required this.baseUrl, required this.model})
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 4),
          receiveTimeout: const Duration(seconds: 90),
          sendTimeout: const Duration(seconds: 10),
        ));

  @override
  String get id => 'ollama:$model';

  /// راهنمای مرحلهٔ پداگوژیک فعلی برای مدل — تا جریان «تدریس → سؤال →
  /// مثال» حتی وقتی موتور محلی Ollama فعال است دقیقاً رعایت شود.
  String _stageInstruction(AiIntent intent) {
    switch (intent) {
      case AiIntent.startLesson:
        return 'شاگرد تازه این بخش را شروع کرده — محتوای بخش را ساده و قدم‌به‌قدم توضیح بده، و در پایان یک سؤال کوتاه درک مطلب از همین بخش بپرس.';
      case AiIntent.nextSection:
        return 'شاگرد آمادهٔ ادامهٔ درس است — بخش بعدی کتاب را تدریس کن و در پایان یک سؤال کوتاه درک مطلب بپرس.';
      case AiIntent.giveExample:
        return 'شاگرد یک مثال خواسته — فقط یک مثال واقعی و ملموس (ترجیحاً بومی افغانستان) از همین بخش کتاب بزن.';
      case AiIntent.askQuestion:
        return 'شاگرد می‌خواهد آزموده شود — فقط یک سؤال کوتاه درک مطلب از همین بخش بپرس، بدون تدریس دوباره.';
      case AiIntent.answerAttempt:
        return 'شاگرد به سؤال قبلی پاسخ داده — پاسخش را با محبت ارزیابی کن: اگر درست بود تشویقش کن، اگر نه با مهربانی راهنمایی‌اش کن (بدون سرزنش) و پاسخ درست را نشانش بده.';
      case AiIntent.freeQuestion:
        return 'شاگرد یک سؤال آزاد پرسیده — از روی متن کتاب پاسخ بده؛ اگر خارج از موضوع بود، با مهربانی به درس فعلی برش گردان.';
    }
  }

  @override
  Future<AiEngineResponse> respond(AiEngineRequest r) async {
    final contextSections = r.openDomain
        ? const <BookSection>[]
        : (r.currentSection != null
            ? [r.currentSection!]
            : BookSectionUtils.findRelevant(r.allSections, r.studentMessage, topN: 3));
    final contextText = contextSections.map((s) => '[${s.heading}]\n${s.content}').join('\n\n');

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
فقط بر اساس متن زیر از کتاب درسی رسمی نصاب تعلیمی افغانستان تدریس کن، سؤال بپرس و مثال بده. اگر پاسخ در متن نیست، صادقانه بگو که در این بخش از کتاب موجود نیست.
همیشه به زبان دری (فارسی) و با لحنی گرم، ساده و تشویق‌کننده برای یک دانش‌آموز دختر پاسخ بده. هرگز شاگرد را سرزنش نکن؛ همیشه دلگرمی بده.

مرحلهٔ فعلی درس: ${_stageInstruction(r.intent)}

متن کتاب:
$contextText
'''
            '${difficultyHintSuffix(r.difficultyHint)}'
            '${r.intent == AiIntent.answerAttempt ? kAnswerCorrectnessInstruction : ''}';

    final messages = [
      {'role': 'system', 'content': systemPrompt},
      ...r.history.take(10).map((m) => {
            'role': m.sender.name == 'ai' ? 'assistant' : 'user',
            'content': m.body,
          }),
      {'role': 'user', 'content': r.studentMessage},
    ];

    try {
      final response = await _dio.post(
        '$baseUrl/api/chat',
        data: {
          'model': model,
          'messages': messages,
          'stream': false,
        },
      );
      final rawContent = response.data is Map
          ? (response.data['message']?['content'] as String?)?.trim()
          : null;
      if (rawContent == null || rawContent.isEmpty) {
        throw OllamaUnavailableException('پاسخ خالی از Ollama دریافت شد.');
      }
      final parsed = r.intent == AiIntent.answerAttempt
          ? parseCorrectnessMarker(rawContent)
          : CorrectnessParseResult(rawContent, null);
      final content = parsed.body;
      return AiEngineResponse(
        body: content,
        sourceReference: contextSections.isNotEmpty
            ? '${contextSections.first.bookTitle} — بخش ${contextSections.first.index + 1}'
            : null,
        posedNewQuestion: content.contains('؟') || content.contains('?'),
        wasCorrectAttempt: parsed.wasCorrect,
      );
    } on DioException catch (e) {
      throw OllamaUnavailableException('اتصال به Ollama ناموفق بود: ${e.message}');
    }
  }
}
