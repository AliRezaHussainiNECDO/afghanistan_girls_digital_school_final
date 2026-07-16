import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../shared_models/subject.dart';
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
  const AiVoiceAskSheet({
    super.key,
    required this.subjectId,
    required this.lessonId,
    required this.lessonTitle,
    required this.lessonContent,
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
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _speakingId = null);
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
        _snack('صدا تشخیص داده نشد؛ لطفاً دوباره تلاش کنید یا تایپ کنید.');
        return;
      }
      await _sendText(text);
    } else {
      if (!await _recorder.hasPermission()) {
        _snack('برای صحبت با معلم، دسترسی میکروفون لازم است.');
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
      if (mounted) setState(() => _speakingId = null);
      return;
    }
    setState(() => _speakingId = msg.id);
    final path = await voice.synthesize(msg.body);
    if (!mounted) return;
    if (path == null) {
      setState(() => _speakingId = null);
      _snack('پخش صوتی در حال حاضر در دسترس نیست.');
      return;
    }
    await _player.play(DeviceFileSource(path));
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiLessonConversationProvider(_focus));
    final voiceEnabled = ref.watch(aiVoiceServiceProvider) != null;
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.72,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                      Text('پرسش از معلم — ${widget.lessonTitle}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      Text(
                        voiceEnabled
                            ? '${_subject.nameFa} · میکروفون را بزنید و دربارهٔ همین درس بپرسید'
                            : '${_subject.nameFa} · سوال خود را دربارهٔ همین درس تایپ کنید',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Text(
                      voiceEnabled
                          ? 'روی میکروفون بزنید و دربارهٔ همین درس سوال کنید.'
                          : 'سوال خود را دربارهٔ همین درس بنویسید.',
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
                            child: Text('معلم در حال فکر کردن است...',
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
                                              _speakingId == msg.id ? 'توقف' : 'شنیدن',
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
                            ? 'در حال ضبط صدا... برای ارسال، دوباره میکروفون را بزنید'
                            : 'سوال خود را بپرسید...',
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
                            tooltip: _isRecording ? 'توقف و ارسال' : 'صحبت با معلم',
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
      ),
    );
  }
}
