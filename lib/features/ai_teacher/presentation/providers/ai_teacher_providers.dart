import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../admin/ai_teacher_management/presentation/providers/ai_teacher_management_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../curriculum_library/data/datasources/curriculum_library_local_datasource.dart';
import '../../../curriculum_library/presentation/providers/curriculum_library_providers.dart'
    show curriculumLibraryDataSourceProvider;
import '../../data/datasources/ai_semantic_search_datasource.dart';
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

/// کتابخانهٔ نصاب که معلم هوشمند از آن تدریس می‌کند — **باید** همان سوییچ
/// Live/Local بقیهٔ برنامه (`curriculumLibraryDataSourceProvider`) را دنبال
/// کند. رفع اشکال: قبلاً همیشه به `CurriculumLibraryLocalDataSource` (کش
/// محلیِ مخصوص هر دستگاه، فقط SharedPreferences) قفل بود — یعنی کتاب‌هایی
/// که مدیر روی سرور آپلود/ساختاربندی می‌کرد هرگز روی دستگاه شاگرد دیده
/// نمی‌شدند و «پرسش از معلم» همیشه می‌گفت «هیچ کتابی آپلود نشده»، حتی وقتی
/// کتاب واقعاً روی سرور و منتشرشده بود.
final curriculumLibraryForAiProvider = Provider<CurriculumLibraryDataSource>(
  (ref) => ref.watch(curriculumLibraryDataSourceProvider),
);

/// سرویس صدای معلم AI — همیشه ساخته می‌شود تا دکمه‌های صدا («شنیدن درس»،
/// «صحبت با معلم») در همهٔ حالت‌ها (Mock/Live) نمایش داده شوند؛ خودِ سرویس
/// کاملاً Fail-safe است (هر خطای شبکه/سرور را می‌بلعد و `null` برمی‌گرداند
/// بدون آسیب به تجربهٔ متنی) — پس هیچ نیازی به قایم‌کردنش پشت سوییچ
/// `kUseLiveBackend` نیست؛ قایم‌کردن پشت آن سوییچ باعث می‌شد در تست/توسعهٔ
/// محلی (Mock) دکمه‌های صدا اصلاً دیده نشوند.
final aiVoiceServiceProvider = Provider<AiVoiceRemoteDataSource?>((ref) {
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

/// معماری ۱ — بازیابی معنایی (RAG واقعی)، فقط روی Backend واقعی معنا دارد
/// (نیازمند جدول Embedding سرور). Provider همیشه ساخته می‌شود، خودِ سرویس
/// Fail-safe است.
final aiSemanticSearchDataSourceProvider =
    Provider((ref) => AiSemanticSearchDataSource(ref.watch(apiClientProvider)));

/// معلم هوشمند از روی «شخصیت» تنظیم‌شدهٔ مدیر در «مدیریت معلم هوشمند» کار
/// می‌کند — با این اتصال، تغییری که مدیر برای هر مضمون ذخیره می‌کند واقعاً
/// روی گفت‌وگوی شاگرد اثر می‌گذارد (قبلاً این دو بخش کاملاً جدا بودند).
final aiTeacherDataSourceProvider = Provider((ref) => AiTeacherEngineDataSource(
      library: ref.watch(curriculumLibraryForAiProvider),
      engineProvider: () => ref.read(activeAiEngineProvider),
      personaLookup: (subjectId) async {
        final result = await ref.read(aiTeacherMgmtRepositoryProvider).getPersonaFor(subjectId);
        return result.fold((_) => null, (persona) => persona);
      },
      // ── معماری ۱: بازیابی معنایی — فقط روی Backend واقعی، در غیر این
      // صورت `null` می‌ماند و DataSource بی‌صدا به بازیابی کلمه‌ای برمی‌گردد.
      semanticSearch: kUseLiveBackend
          ? (subjectId, grade, query) => ref.read(aiSemanticSearchDataSourceProvider).search(
                subjectId: subjectId,
                grade: grade,
                query: query,
              )
          : null,
      // ── معماری ۲: لاگ درست/غلط برای آمار دقت + امتیاز مشترک.
      logAttempt: kUseLiveBackend
          ? (subjectId, grade, wasCorrect) async {
              try {
                await ref.read(apiClientProvider).post('/ai-teacher/log-attempt', data: {
                  'subjectId': subjectId,
                  'gradeId': grade,
                  'wasCorrect': wasCorrect,
                });
              } catch (_) {
                // Fail-safe — هرگز گفتگو را مختل نمی‌کند.
              }
            }
          : null,
    ));
final aiTeacherRepositoryProvider =
    Provider<AiTeacherRepository>((ref) => AiTeacherRepositoryImpl(ref.watch(aiTeacherDataSourceProvider)));
final getConversationUseCaseProvider =
    Provider((ref) => GetConversationUseCase(ref.watch(aiTeacherRepositoryProvider)));
final sendMessageUseCaseProvider =
    Provider((ref) => SendMessageUseCase(ref.watch(aiTeacherRepositoryProvider)));

/// وضعیت گفتگو per مضمون — طبق بخش ۵.۷ سند (State Machine چت AI Teacher).
///
/// `grade` = صنف فعال واقعی شاگرد در لحظهٔ ساخت این Notifier (از
/// `activeGradeProvider`). اگر شاگرد ارتقای صنف بگیرد، Provider پایین
/// خودکار یک نمونهٔ تازه با صنف جدید می‌سازد تا معلم هوشمند بلافاصله سراغ
/// کتاب صنف جدید برود.
class AiConversationNotifier extends StateNotifier<List<AiChatMessage>> {
  final Ref ref;
  final String subjectId;
  final int grade;
  bool sending = false;

  AiConversationNotifier(this.ref, this.subjectId, this.grade) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final result = await ref
        .read(getConversationUseCaseProvider)
        .call(GetConversationParams(subjectId: subjectId, grade: grade));
    result.fold((f) => null, (messages) => state = messages);
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    sending = true;
    // ── رفع اشکال «سکوت کامل»: قبلاً اگر هر جای زنجیره (کتابخانه/شبکه) خطا
    // می‌داد، `result.fold((f) => null, ...)` هیچ کاری نمی‌کرد — نه پیام
    // شاگرد نمایش داده می‌شد نه خطایی. حالا پیام شاگرد فوری/optimistic روی
    // صفحه می‌آید (هرگز گم نمی‌شود)، و اگر کل زنجیره — حتی موتور محلی
    // رایگان — شکست بخورد، یک پیام گرم و روشن به‌جای سکوت نشان داده می‌شود.
    final optimisticStudentMsg = AiChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.student,
      body: text,
      timestamp: DateTime.now(),
    );
    state = [...state, optimisticStudentMsg];
    final result = await ref
        .read(sendMessageUseCaseProvider)
        .call(SendMessageParams(subjectId: subjectId, text: text, grade: grade));
    sending = false;
    result.fold(
      (f) => state = [
        ...state,
        AiChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          sender: ChatSender.ai,
          body: 'یک مشکل موقت پیش آمد و نتوانستم پاسخ بدهم. لطفاً دوباره تلاش کن. 🌸',
          timestamp: DateTime.now(),
        ),
      ],
      (_) => _load(),
    );
  }
}

final aiConversationProvider =
    StateNotifierProvider.family<AiConversationNotifier, List<AiChatMessage>, String>(
  (ref, subjectId) {
    final grade = ref.watch(activeGradeProvider);
    return AiConversationNotifier(ref, subjectId, grade);
  },
);

/// شناسهٔ درسی که «پرسش از معلم» باید روی آن متمرکز بماند — برای شناسایی
/// خودِ درس (نه فقط مضمون) در Family Providerهای زیر.
typedef AiLessonFocus = ({String lessonId, String lessonTitle, String lessonContent, String subjectId});

/// گفتگوی معلم هوشمند **متمرکز روی یک درس مشخص** — طبق درخواست کاربر: وقتی
/// شاگرد از داخل یک درس «پرسش از معلم» را باز می‌کند، باید دقیقاً همان درس
/// تدریس/سؤال/ارزیابی شود، نه کل مضمون. تاریخچهٔ هر درس جدا نگه‌داری
/// می‌شود (کلیدبندی بر اساس `lessonId`) تا با رفتن سراغ درس دیگر، گفتگوی
/// درس قبلی گیج‌کننده نماند و همیشه یک تجربهٔ تازه و مرتبط با همان درس باشد.
class AiLessonConversationNotifier extends StateNotifier<List<AiChatMessage>> {
  final Ref ref;
  final AiLessonFocus focus;
  final int grade;
  bool sending = false;

  AiLessonConversationNotifier(this.ref, this.focus, this.grade) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final messages = await ref.read(aiTeacherDataSourceProvider).getLessonConversation(
          lessonId: focus.lessonId,
          lessonTitle: focus.lessonTitle,
          lessonContent: focus.lessonContent,
          subjectId: focus.subjectId,
          grade: grade,
        );
    state = messages;
  }

  Future<void> send(String text) async {
    if (text.trim().isEmpty) return;
    sending = true;
    // همان رفع اشکال «سکوت کامل» بالا — اینجا هم پیام شاگرد فوری نمایش داده
    // می‌شود و شکست کامل زنجیره یک پیام گرم نشان می‌دهد، نه سکوت.
    final optimisticStudentMsg = AiChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      sender: ChatSender.student,
      body: text,
      timestamp: DateTime.now(),
    );
    state = [...state, optimisticStudentMsg];
    try {
      await ref.read(aiTeacherDataSourceProvider).sendLessonMessage(
            lessonId: focus.lessonId,
            lessonTitle: focus.lessonTitle,
            lessonContent: focus.lessonContent,
            subjectId: focus.subjectId,
            grade: grade,
            text: text,
          );
      sending = false;
      await _load();
    } catch (_) {
      sending = false;
      state = [
        ...state,
        AiChatMessage(
          id: 'err_${DateTime.now().millisecondsSinceEpoch}',
          sender: ChatSender.ai,
          body: 'یک مشکل موقت پیش آمد و نتوانستم پاسخ بدهم. لطفاً دوباره تلاش کن. 🌸',
          timestamp: DateTime.now(),
        ),
      ];
    }
  }
}

final aiLessonConversationProvider = StateNotifierProvider.family<AiLessonConversationNotifier,
    List<AiChatMessage>, AiLessonFocus>(
  (ref, focus) {
    final grade = ref.watch(activeGradeProvider);
    return AiLessonConversationNotifier(ref, focus, grade);
  },
);
