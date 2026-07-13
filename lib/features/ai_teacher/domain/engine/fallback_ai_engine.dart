import 'ai_engine.dart';
import 'local_curriculum_ai_engine.dart';
import 'ollama_ai_engine.dart';

/// اگر موتور Ollama فعال باشد ابتدا آن را امتحان می‌کند؛ در صورت هر خطا
/// (نصب‌نشدن Ollama، خاموش بودن سرور، قطعی شبکه) بی‌صدا به موتور محلی
/// رایگان برمی‌گردد تا معلم هوشمند هیچ‌وقت از کار نیفتد.
class FallbackAiEngine implements AiEngine {
  final AiEngine? primary;
  final LocalCurriculumAiEngine _local = LocalCurriculumAiEngine();

  FallbackAiEngine({this.primary});

  @override
  String get id => primary != null ? '${primary!.id}+fallback' : _local.id;

  @override
  Future<AiEngineResponse> respond(AiEngineRequest request) async {
    if (primary == null) return _local.respond(request);
    try {
      return await primary!.respond(request);
    } on OllamaUnavailableException {
      return _local.respond(request);
    } catch (_) {
      return _local.respond(request);
    }
  }
}
