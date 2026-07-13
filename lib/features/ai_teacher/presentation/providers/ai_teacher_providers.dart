import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../curriculum_library/data/datasources/curriculum_library_local_datasource.dart';
import '../../data/datasources/ai_teacher_engine_datasource.dart';
import '../../data/datasources/ai_voice_remote_datasource.dart';
import '../../data/repositories_impl/ai_teacher_repository_impl.dart';
import '../../domain/engine/ai_engine.dart';
import '../../domain/engine/fallback_ai_engine.dart';
import '../../domain/engine/ollama_ai_engine.dart';
import '../../domain/engine/worker_ai_engine.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_teacher_repository.dart';
import '../../domain/usecases/ai_teacher_usecases.dart';
import 'ai_engine_settings_provider.dart';

final curriculumLibraryForAiProvider = Provider((ref) => CurriculumLibraryLocalDataSource());

/// سرویس صدای معلم AI — فقط در حالت Backend واقعی فعال است؛ در حالت Mock
/// `null` است تا دکمه‌های صدا نمایش داده نشوند (Fail-safe، بدون آسیب به چت متنی).
final aiVoiceServiceProvider = Provider<AiVoiceRemoteDataSource?>((ref) {
  if (!kUseLiveBackend) return null;
  return AiVoiceRemoteDataSource(ref.watch(apiClientProvider));
});

/// موتور فعلی معلم هوشمند، به ترتیب اولویت:
///   ۱) اگر `kUseLiveBackend` روشن باشد → LLM ابری از طریق Worker (کلید امن
///      روی سرور)، با fallback خودکار به موتور محلی رایگان (بخش ۲۱.۴).
///   ۲) اگر مدیر Ollama را روشن کرده باشد → موتور محلی نصب‌شده روی کامپیوتر.
///   ۳) در غیر این صورت → موتور محلی مبتنی بر متن کتاب (پیش‌فرض رایگان).
final activeAiEngineProvider = Provider<AiEngine>((ref) {
  if (kUseLiveBackend) {
    return FallbackAiEngine(primary: WorkerAiEngine(ref.watch(apiClientProvider)));
  }
  final settings = ref.watch(aiEngineSettingsProvider);
  if (!settings.useOllama) return FallbackAiEngine();
  return FallbackAiEngine(
    primary: OllamaAiEngine(baseUrl: settings.baseUrl, model: settings.model),
  );
});

final aiTeacherDataSourceProvider = Provider((ref) => AiTeacherEngineDataSource(
      library: ref.watch(curriculumLibraryForAiProvider),
      engineProvider: () => ref.read(activeAiEngineProvider),
    ));
final aiTeacherRepositoryProvider =
    Provider<AiTeacherRepository>((ref) => AiTeacherRepositoryImpl(ref.watch(aiTeacherDataSourceProvider)));
final getConversationUseCaseProvider =
    Provider((ref) => GetConversationUseCase(ref.watch(aiTeacherRepositoryProvider)));
final sendMessageUseCaseProvider =
    Provider((ref) => SendMessageUseCase(ref.watch(aiTeacherRepositoryProvider)));

/// وضعیت گفتگو per مضمون — طبق بخش ۵.۷ سند (State Machine چت AI Teacher).
class AiConversationNotifier extends StateNotifier<List<AiChatMessage>> {
  final Ref ref;
  final String subjectId;
  bool sending = false;

  AiConversationNotifier(this.ref, this.subjectId) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final result = await ref.read(getConversationUseCaseProvider).call(subjectId);
    result.fold((f) => null, (messages) => state = messages);
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    sending = true;
    final result =
        await ref.read(sendMessageUseCaseProvider).call(SendMessageParams(subjectId: subjectId, text: text));
    sending = false;
    result.fold((f) => null, (_) => _load());
  }
}

final aiConversationProvider =
    StateNotifierProvider.family<AiConversationNotifier, List<AiChatMessage>, String>(
  (ref, subjectId) => AiConversationNotifier(ref, subjectId),
);
