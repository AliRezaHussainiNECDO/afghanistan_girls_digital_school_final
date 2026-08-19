import 'dart:async' show unawaited;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/tts_text_splitter.dart';
import '../../../../shared_models/subject.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../competition/presentation/providers/competition_providers.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../../../grade_map/presentation/providers/grade_map_providers.dart';
import '../../../student_dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/ai_teacher_providers.dart';

/// شیت گفتگوی صوتی با معلم AI — همیشه از داخل صفحهٔ یک درس مشخص باز می‌شود
/// و طبق درخواست کاربر روی **دقیقاً همان درس** متمرکز می‌ماند: معلم هوشمند
/// از روی متن همان درس تدریس می‌کند، دربارهٔ آن سؤال می‌پرسد و پاسخ شاگرد
/// را ارزیابی می‌کند — نه کل کتاب/مضمون. این رفتار برای هر مضمون و هر
/// صنفی یکسان است چون محتوا مستقیماً از همان درسِ روی صفحه می‌آید (بخش ۲۱.۴).
///
///  • میکروفون → ضبط → STT (Whisper روی Worker) → ارسال به معلم AI همین درس
///  • «شنیدن» → TTS پاسخ معلم با صدای خانم دری (Azure؛ صدا با AZURE_TTS_VOICE
///    در wrangler.toml قابل تنظیم است)
///  • تاریخچهٔ گفتگو به‌ازای همین درس ذخیره می‌شود (`aiLessonConversationProvider`)
///    تا با رفتن سراغ درس دیگر، گفتگوی قبلی گیج‌کننده نماند.
///
/// اگر Backend واقعی فعال نباشد (`USE_LIVE_BACKEND=false`)، دکمه‌های صوتی
/// پنهان می‌شوند ولی پرسش متنی همچنان کار می‌کند.
Future<void> showAiVoiceAskSheet(
  BuildContext context, {
  required String subjectId,
  required String lessonId,
  required String lessonTitle,
  required String lessonContent,
  String? chapterId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: AiVoiceAskSheet(
        subjectId: subjectId,
        chapterId: chapterId,
        lessonId: lessonId,
        lessonTitle: lessonTitle,
        lessonContent: lessonContent,
      ),
    ),
  );
}

class AiVoiceAskSheet extends ConsumerStatefulWidget {
  final String subjectId;
  final String lessonId;
  final String lessonTitle;
  final String lessonContent;

  /// شناسهٔ فصلِ همین درس — فقط برای Invalidate کردن دقیقِ
  /// `lessonsProvider(chapterId)` بعد از «یاد گرفتم» لازم است (رفع اشکال
  /// هماهنگی نصاب درسی/امروز، نگاه کنید به [_markLearned])؛ اختیاری است چون
  /// [showAiVoiceAskSheet] در حالت غیر-Embedded ممکن است بدون چپتر صدا زده شود.
  final String? chapterId;

  /// حالت «کلاس تعاملی تمام‌صفحه» (طبق درخواست کاربر): وقتی true باشد، همین
  /// ویجت مستقیماً بدنهٔ (body) صفحهٔ درس می‌شود — بدون دستگیرهٔ کشیدن شیت و
  /// بدون سقف ارتفاع ۷۲٪؛ کل فضای صفحه را می‌گیرد تا شاگرد به‌محض ورود به
  /// درس، یک‌راست وارد گفت‌وگو با معلم هوشمند شود.
  final bool embedded;

  const AiVoiceAskSheet({
    super.key,
    required this.subjectId,
    this.chapterId,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonContent,
    this.embedded = false,
  });

  @override
  ConsumerState<AiVoiceAskSheet> createState() => _AiVoiceAskSheetState();
}

class _AiVoiceAskSheetState extends ConsumerState<AiVoiceAskSheet> {
  final _controller = TextEditingController();
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _scroll = ScrollController();

  bool _sending = false;
  bool _isRecording = false;
  bool _transcribing = false;
  String? _speakingId;

  // ── پخشِ صدای پاسخِ معلم — قطعه‌به‌قطعه با بازآزمایی (Fail-safe) ──
  //
  // رفع اشکالِ ریشه‌ای «صدای متنِ طولانی هنوز پلی نمی‌شود»: قاعدهٔ
  // «هیچ‌قطعه‌ای از سقفِ مجاز بزرگ‌تر نشود + هر قطعه تا ۲ بار دوباره تلاش
  // شود + یک قطعهٔ خراب کل جلسه را متوقف نکند» قبلاً فقط در صفحهٔ درس
  // («شنیدنِ درس») پیاده شده بود. اما همین دکمهٔ 🔊 اینجا — که پاسخِ کاملِ
  // معلمِ هوشمند را در یک درخواستِ تکی و بدون‌سقف می‌فرستاد — دقیقاً همان
  // مسیرِ فراموش‌شده بود که با یک پاسخِ طولانی (که برای تولیدِ صدایش بیش از
  // زمانِ انتظار مجاز طول می‌کشید) دوباره همان خطای «در دسترس نیست» را
  // نشان می‌داد. حالا این متد هم از همان تابعِ مشترکِ [splitForTts] و همان
  // منطقِ قطعه‌به‌قطعهٔ [LessonDetailScreen] پیروی می‌کند.
  List<String> _speakChunks = const [];
  int _speakIndex = 0;
  bool _speakAnyChunkPlayed = false;
  AiChatMessage? _speakingMsg;

  // رفعِ اشکالِ گزارش‌شده («صدا چند لحظه معطل می‌ماند تا پلی شود، خسته‌کننده
  // است») — دقیقاً همان ترفندِ `LessonDetailScreen`: هر قطعه فقط یک‌بار
  // ساخته می‌شود (نتیجه در این Mapها کش می‌شود، به‌ازای هر پیام جداگانه چون
  // چند پاسخِ معلم می‌توانند هم‌زمان روی صفحه باشند) و همین‌که پخشِ یک قطعه
  // *شروع* شد، ساختِ قطعهٔ بعدی هم بلافاصله در پس‌زمینه آغاز می‌شود — تا وقتی
  // نوبتش برسد معمولاً از قبل آماده است. علاوه‌براین، همین که خودِ پاسخِ
  // معلم می‌رسد (نه از لحظهٔ زدنِ دکمهٔ 🔊)، صدای قطعهٔ *اولش* هم پیشاپیش و
  // در پس‌زمینه ساخته می‌شود؛ نگاه کنید `_prefetchSpeakChunk0` و `ref.listen`
  // پایینِ build().
  final Map<String, List<String>> _speakChunksByMsg = {};
  final Map<String, Map<int, Future<String?>>> _speakFuturesByMsg = {};
  final Set<String> _speakPrefetchStarted = {};

  /// تولیدِ صدای یک قطعه با تلاشِ مجدد (تا ۲ بارِ دیگر، مکثِ فزاینده).
  Future<String?> _synthesizeWithRetry(String chunk, {int attempt = 0}) async {
    final voice = ref.read(aiVoiceServiceProvider);
    if (voice == null) return null;
    final path = await voice.synthesize(chunk);
    if (path != null || attempt >= 2) return path;
    await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
    return _synthesizeWithRetry(chunk, attempt: attempt + 1);
  }

  List<String> _chunksFor(AiChatMessage msg) =>
      _speakChunksByMsg.putIfAbsent(msg.id, () => splitForTts(msg.body));

  /// اگر ساختِ صدای قطعهٔ [index] از همین پیام قبلاً آغاز نشده، همین حالا
  /// (در پس‌زمینه) آغازش می‌کند و Future مشترک را برمی‌گرداند.
  Future<String?> _ensureSpeakChunkFuture(AiChatMessage msg, int index) {
    final chunks = _chunksFor(msg);
    if (index < 0 || index >= chunks.length) return Future.value(null);
    final futures = _speakFuturesByMsg.putIfAbsent(msg.id, () => {});
    return futures.putIfAbsent(index, () => _synthesizeWithRetry(chunks[index]));
  }

  /// یک‌بار برای هر پیام، همین که پاسخِ تازهٔ معلم می‌رسد (پیش از اینکه
  /// شاگرد اصلاً دکمهٔ 🔊 را بزند)، صدای قطعهٔ *اول* آن را در پس‌زمینه
  /// می‌سازد — هزینه عمداً کم نگه داشته شده (فقط یک قطعهٔ کوچک، نه کل پاسخ).
  void _prefetchSpeakChunk0(AiChatMessage msg) {
    if (!_speakPrefetchStarted.add(msg.id)) return;
    if (ref.read(aiVoiceServiceProvider) == null) return;
    _ensureSpeakChunkFuture(msg, 0);
  }

  /// «این درس را یاد گرفتم» — کار خانگی فقط با زدن همین دکمه ساخته می‌شود
  /// (نه با باز کردن درس). برای هر درس فقط یک کار خانگی؛ زدن دوباره روی
  /// همان درس کار خانگی تازه نمی‌دهد (سرور idempotent است).
  bool _learning = false;
  bool _learnedThisSession = false;

  Future<void> _markLearned() async {
    if (_learning) return;
    setState(() => _learning = true);
    final result = await ref.read(markLessonLearnedUseCaseProvider).call(widget.lessonId);
    if (!mounted) return;
    setState(() => _learning = false);
    result.fold(
      (f) => _snack(context.tr('curriculum.homeworkAssignFailed')),
      (r) {
        // اتمام موقت سهمیهٔ رایگان Gemini (429) — پیام محترمانهٔ «قفل موقت»؛
        // شاگرد بعداً دوباره دکمه را می‌زند (سرور idempotent است).
        if (r.rateLimited) {
          _snack(context.tr('curriculum.aiRateLimited'));
          return;
        }
        setState(() => _learnedThisSession = true);
        // ── رفع اشکال ریشه‌ای هماهنگی «نصاب درسی» ↔ «امروز»: قبلاً بعد از
        // ارسال کار خانگی هیچ Providerای Invalidate نمی‌شد — یعنی
        // `lessonsProvider(chapterId)`/`chaptersProvider(subjectId)` (که هم
        // LessonsScreen/ChaptersScreen و هم `todaySubjectPointerProvider` در
        // «امروز» دقیقاً از همین دو می‌خوانند) تا خروج کامل از کل پشتهٔ
        // ناوبری همان وضعیت قفلِ *قبل از* همین کار خانگی را نشان می‌دادند؛
        // یعنی «درس بعدی باز شد» فقط با تأخیر/گاهی اصلاً دیده نمی‌شد. حالا
        // بلافاصله همین‌جا Invalidate می‌شود — چون این دو Provider منبع واحد
        // هر دو بخش‌اند، هر دو همین لحظه با هم به‌روز می‌شوند.
        if (r.assigned || r.alreadyAssigned) {
          ref.invalidate(chaptersProvider(widget.subjectId));
          final chapterId = widget.chapterId;
          if (chapterId != null) ref.invalidate(lessonsProvider(chapterId));
          ref.invalidate(lessonProvider(widget.lessonId));
          final studentId = ref.read(authSessionProvider)?.id;
          if (studentId != null) {
            ref.invalidate(dashboardSummaryProvider(studentId));
            ref.invalidate(gradeMapProvider);
          }
          // رفع اشکال (H6 — کهنه‌ماندنِ رقابت/جدولِ امتیازات): «یاد گرفتم»
          // می‌تواند امتیاز فعالیت و/یا پاداشِ تکمیلِ فصل بدهد (progress.ts::
          // recordLessonView/checkAndCompleteChapter) — قبلاً این هیچ اثری
          // روی صفحهٔ رقابت/جدولِ امتیازات نداشت تا شاگرد خودش دستی صفحه را
          // باز/بسته می‌کرد. حالا دقیقاً مثلِ claimMission/claimDailyQuest
          // در competition_providers.dart بلافاصله تازه می‌شود.
          ref.read(competitionRefreshProvider.notifier).state++;
        }
        if (r.assigned) {
          _snack(context.tr('curriculum.homeworkAssigned'));
        } else if (r.alreadyAssigned) {
          _snack(context.tr('curriculum.homeworkAlreadyAssigned'));
        } else {
          // AI هنوز پیکربندی نشده یا خطای موقتی — کار خانگی ساخته نشد.
          _snack(context.tr('curriculum.homeworkAssignFailed'));
        }
      },
    );
  }

  Subject get _subject =>
      mockSubjects.firstWhere((s) => s.id == widget.subjectId, orElse: () => mockSubjects.first);

  AiLessonFocus get _focus => (
        lessonId: widget.lessonId,
        lessonTitle: widget.lessonTitle,
        lessonContent: widget.lessonContent,
        subjectId: widget.subjectId,
      );

  @override
  void initState() {
    super.initState();
    // با پایانِ پخشِ هر قطعه، خودکار سراغِ قطعهٔ بعدیِ همان پاسخ می‌رویم —
    // نه اینکه فقط _speakingId را پاک کنیم (که فقط برای متنِ تک‌قطعه‌ای درست
    // بود).
    _player.onPlayerComplete.listen((_) {
      final msg = _speakingMsg;
      if (mounted && msg != null) _playSpeakChunkAt(msg, _speakIndex);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    _player.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    await ref.read(aiLessonConversationProvider(_focus).notifier).send(t);
    if (!mounted) return;
    setState(() => _sending = false);
    // نوار پیشرفت «بخش X از Y» بعد از هر پیام ممکن است تغییر کرده باشد
    // (پیشرفت خودکار به بخش بعدی، یا تکمیل درس) — دوباره خوانده می‌شود.
    ref.invalidate(aiLessonProgressProvider(_focus));
    // پایین‌رفتن خودکار برای دیدن پاسخ تازه.
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  /// ضبط صدای دانش‌آموز → STT → ارسال به معلم AI (Fail-safe).
  Future<void> _toggleRecord() async {
    final voice = ref.read(aiVoiceServiceProvider);
    if (voice == null) return;
    if (_isRecording) {
      final path = await _recorder.stop();
      if (!mounted) return;
      setState(() => _isRecording = false);
      if (path == null) return;
      setState(() => _transcribing = true);
      final text = await voice.transcribe(path);
      if (!mounted) return;
      setState(() => _transcribing = false);
      if (text == null || text.trim().isEmpty) {
        _snack(context.tr('aiTeacher.voiceNotRecognized'));
        return;
      }
      await _sendText(text);
    } else {
      final hasPermission = await _recorder.hasPermission();
      if (!mounted) return;
      if (!hasPermission) {
        _snack(context.tr('aiTeacher.micPermissionRequired'));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/ai_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (!mounted) return;
      setState(() => _isRecording = true);
    }
  }

  /// پخش پاسخ معلم با صدای خانم دری (TTS). دوباره‌فشردن = توقف.
  Future<void> _speak(AiChatMessage msg) async {
    final voice = ref.read(aiVoiceServiceProvider);
    if (voice == null) return;
    if (_speakingId == msg.id) {
      await _player.stop();
      if (mounted) {
        setState(() {
          _speakingId = null;
          _speakingMsg = null;
          _speakIndex = 0;
        });
      }
      return;
    }
    // اگر پیامِ دیگری در حالِ پخش بود، اول متوقفش کن — یک بار در لحظه فقط.
    await _player.stop();
    if (!mounted) return;
    setState(() {
      _speakingId = msg.id;
      _speakingMsg = msg;
      // معمولاً از قبل با `_prefetchSpeakChunk0` ساخته شده — همان لیستِ کش‌شده
      // استفاده می‌شود تا دوباره‌محاسبه نشود.
      _speakChunks = _chunksFor(msg);
      _speakIndex = 0;
      _speakAnyChunkPlayed = false;
    });
    await _playSpeakChunkAt(msg, 0);
  }

  /// پخشِ قطعهٔ [index] از پاسخِ [msg] — با تا ۲ بار بازآزماییِ هر قطعه
  /// (داخلِ `_synthesizeWithRetry`) و ادامه به قطعهٔ بعدی به‌جای توقفِ کاملِ
  /// پخش اگر فقط همان یک قطعه شکست خورد. پیامِ «در دسترس نیست» فقط وقتی
  /// نشان داده می‌شود که حتی قطعهٔ اول هم (بعد از تلاش‌های تکراری) شکست
  /// بخورد. رفعِ اشکالِ «صدا معطل می‌ماند»: همین‌که پخشِ این قطعه آغاز شد،
  /// بلافاصله ساختِ قطعهٔ بعدی هم در پس‌زمینه شروع می‌شود.
  Future<void> _playSpeakChunkAt(AiChatMessage msg, int index) async {
    if (!mounted || _speakingId != msg.id) return;
    final chunks = _chunksFor(msg);
    if (index >= chunks.length) {
      setState(() {
        _speakingId = null;
        _speakingMsg = null;
      });
      return;
    }
    final path = await _ensureSpeakChunkFuture(msg, index);
    if (!mounted || _speakingId != msg.id) return;
    if (path == null) {
      if (!_speakAnyChunkPlayed) {
        setState(() {
          _speakingId = null;
          _speakingMsg = null;
        });
        _snack(context.tr('curriculum.audioUnavailable'));
        return;
      }
      setState(() => _speakIndex = index + 1);
      return _playSpeakChunkAt(msg, index + 1);
    }
    setState(() {
      _speakAnyChunkPlayed = true;
      _speakIndex = index + 1;
    });
    unawaited(_ensureSpeakChunkFuture(msg, index + 1));
    await _player.play(DeviceFileSource(path));
    // رفعِ بازخوردِ کاربران («صدا خیلی آهسته/خسته‌کننده است»): سرعتِ پخش
    // باید *بعد* از play() تنظیم شود، چون بارگذاریِ منبعِ تازه سرعت را به
    // پیش‌فرضِ ۱ برمی‌گرداند (نگاه کنید به kAiVoicePlaybackRate).
    unawaited(_player.setPlaybackRate(kAiVoicePlaybackRate));
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiLessonConversationProvider(_focus));
    // پیش‌بارگذاریِ صدای هر پاسخِ تازهٔ معلم، همین لحظه‌ای که به گفتگو اضافه
    // می‌شود — نه از لحظهٔ زدنِ 🔊 (رفعِ اشکالِ «صدا معطل می‌ماند»؛ نگاه کنید
    // به کامنتِ `_prefetchSpeakChunk0` بالا).
    ref.listen<List<AiChatMessage>>(aiLessonConversationProvider(_focus), (prev, next) {
      if (next.isEmpty) return;
      final last = next.last;
      if (last.sender == ChatSender.ai) _prefetchSpeakChunk0(last);
    });
    final voiceEnabled = ref.watch(aiVoiceServiceProvider) != null;
    final progressAsync = ref.watch(aiLessonProgressProvider(_focus));
    final scheme = Theme.of(context).colorScheme;

    final content = Column(
        children: [
          // دستگیرهٔ کشیدن فقط در حالت شیت پایین‌رونده — در حالت تمام‌صفحه حذف.
          if (!widget.embedded) ...[
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    gradient: AppColors.sunriseGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.smart_toy_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('aiTeacher.askAboutLesson', {'lesson': widget.lessonTitle}),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        voiceEnabled
                            ? context.tr('aiTeacher.tapMicHint', {'subject': _subject.nameFa})
                            : context.tr('aiTeacher.typeQuestionHint', {'subject': _subject.nameFa}),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                // ── «این درس را یاد گرفتم» — تنها راه دریافت کار خانگی؛
                // یک‌بار برای هر درس (زدن دوباره = کار خانگی تکراری نمی‌دهد).
                _learning
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: SizedBox(
                            width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : FilledButton.tonalIcon(
                        onPressed: _learnedThisSession ? null : _markLearned,
                        icon: Icon(
                            _learnedThisSession
                                ? Icons.check_circle_rounded
                                : Icons.school_rounded,
                            size: 18),
                        label: Text(
                          context.tr('curriculum.lessonLearnedButton'),
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                        ),
                      ),
              ],
            ),
          ),
          // ── نوار پیشرفت زندهٔ «بخش X از Y» — طبق درخواست کاربر برای
          // دیزاینی پویاتر که همیشه نشان دهد شاگرد دقیقاً کجای درس است و
          // با پیشرفت گام‌به‌گامِ تازه (تسهیم درس به بخش‌های کوتاه) هماهنگ
          // است؛ بعد از هر پیام خودکار به‌روز می‌شود (نگاه کنید به `_sendText`).
          progressAsync.when(
            data: (p) {
              if (p.total <= 1 && !p.completed) return const SizedBox.shrink();
              final fraction = p.total > 0 ? (p.current / p.total).clamp(0.0, 1.0) : 0.0;
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          p.completed
                              ? context.tr('aiTeacher.lessonCompleted')
                              : context.tr('aiTeacher.sectionProgress',
                                  {'current': '${p.current}', 'total': '${p.total}'}),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: p.completed ? scheme.primary : scheme.onSurfaceVariant),
                        ),
                        if (!p.completed)
                          Text('${(fraction * 100).round()}٪',
                              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: fraction),
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => LinearProgressIndicator(
                          value: value,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(
                              p.completed ? scheme.primary : scheme.secondary),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const Divider(height: 16),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      voiceEnabled
                          ? context.tr('aiTeacher.emptyStateMic')
                          : context.tr('aiTeacher.emptyStateType'),
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: messages.length + (_sending ? 1 : 0),
                    itemBuilder: (context, i) {
                      if (i >= messages.length) {
                        return Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(context.tr('aiTeacher.thinking'),
                                style: Theme.of(context).textTheme.bodySmall),
                          ),
                        );
                      }
                      final msg = messages[i];
                      final isAi = msg.sender == ChatSender.ai;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment:
                              isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                                decoration: BoxDecoration(
                                  gradient: isAi ? null : AppColors.heroGradient,
                                  color: isAi ? scheme.surfaceContainer : null,
                                  borderRadius: BorderRadius.circular(AppRadii.md),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(msg.body,
                                        style: TextStyle(
                                            color: isAi ? scheme.onSurface : Colors.white)),
                                    if (isAi && voiceEnabled) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: () => _speak(msg),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _speakingId == msg.id
                                                  ? Icons.stop_circle_rounded
                                                  : Icons.volume_up_rounded,
                                              size: 18,
                                              color: scheme.primary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _speakingId == msg.id
                                                  ? context.tr('curriculum.stopListening')
                                                  : context.tr('aiTeacher.listen'),
                                              style: TextStyle(
                                                  fontSize: 11, color: scheme.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: _isRecording
                            ? context.tr('aiTeacher.recordingHint')
                            : context.tr('aiTeacher.askYourQuestion'),
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) {
                        final t = _controller.text;
                        _controller.clear();
                        _sendText(t);
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (voiceEnabled)
                    _transcribing
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : IconButton.filledTonal(
                            tooltip: _isRecording
                                ? context.tr('aiTeacher.stopAndSend')
                                : context.tr('aiTeacher.talkToTeacher'),
                            icon: Icon(
                              _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
                              color: _isRecording ? Colors.red : null,
                            ),
                            onPressed: _sending ? null : _toggleRecord,
                          ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _sending
                        ? null
                        : () {
                            final t = _controller.text;
                            _controller.clear();
                            _sendText(t);
                          },
                  ),
                ],
              ),
            ),
          ),
        ],
      );

    // حالت تمام‌صفحه (کلاس تعاملی): کل بدنهٔ صفحه — حالت شیت: سقف ۷۲٪ ارتفاع.
    return widget.embedded
        ? content
        : SizedBox(height: MediaQuery.of(context).size.height * 0.72, child: content);
  }
}
