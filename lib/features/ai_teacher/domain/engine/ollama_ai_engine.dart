import 'package:dio/dio.dart';
import '../../../curriculum_library/domain/entities/curriculum_book.dart';
import 'ai_engine.dart';
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
همیشه به زبان دری (فارسی) و با لحنی گرم، ساده و تشویق‌کننده برای یک دانش‌آموز دختر پاسخ بده.

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
      final response = await _dio.post(
        '$baseUrl/api/chat',
        data: {
          'model': model,
          'messages': messages,
          'stream': false,
        },
      );
      final content = response.data is Map
          ? (response.data['message']?['content'] as String?)?.trim()
          : null;
      if (content == null || content.isEmpty) {
        throw OllamaUnavailableException('پاسخ خالی از Ollama دریافت شد.');
      }
      return AiEngineResponse(
        body: content,
        sourceReference: contextSections.isNotEmpty
            ? '${contextSections.first.bookTitle} — بخش ${contextSections.first.index + 1}'
            : null,
        posedNewQuestion: content.contains('؟') || content.contains('?'),
      );
    } on DioException catch (e) {
      throw OllamaUnavailableException('اتصال به Ollama ناموفق بود: ${e.message}');
    }
  }
}
