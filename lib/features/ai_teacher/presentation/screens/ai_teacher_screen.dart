import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../shared_models/subject.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../data/datasources/ai_teacher_engine_datasource.dart';
import '../../domain/entities/chat_message.dart';
import '../providers/ai_teacher_providers.dart';
import '../providers/learning_progress_providers.dart';

class AiTeacherScreen extends ConsumerStatefulWidget {
  const AiTeacherScreen({super.key});

  @override
  ConsumerState<AiTeacherScreen> createState() => _AiTeacherScreenState();
}

class _AiTeacherScreenState extends ConsumerState<AiTeacherScreen> {
  String _subjectId = mockSubjects.first.id;
  final _controller = TextEditingController();
  bool _sending = false;

  // ── صدا (کاملاً ماژولار و Fail-safe) ──
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  bool _isRecording = false;
  bool _transcribing = false;
  String? _speakingId; // شناسهٔ پیام در حال پخش صوتی

  @override
  void initState() {
    super.initState();
    // اگر از تقسیم اوقات/داشبورد با مضمون مشخص آمده باشیم، همان باز شود.
    final initial = ref.read(aiTeacherInitialSubjectProvider);
    if (initial != null && mockSubjects.any((s) => s.id == initial)) {
      _subjectId = initial;
      // مصرف شد — دفعهٔ بعد پیش‌فرض عادی بماند.
      Future.microtask(
          () => ref.read(aiTeacherInitialSubjectProvider.notifier).state = null);
    }
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _speakingId = null);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _recorder.dispose();
    _player.dispose();
    super.dispose();
  }

  Subject get _subject => mockSubjects.firstWhere((s) => s.id == _subjectId);

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await _sendText(text);
  }

  Future<void> _sendText(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    setState(() => _sending = true);
    await ref.read(aiConversationProvider(_subjectId).notifier).send(t);
    if (mounted) setState(() => _sending = false);
  }

  /// ضبط صدای دانش‌آموز → تبدیل به متن (STT) → ارسال به معلم AI.
  Future<void> _toggleRecord() async {
    final voice = ref.read(aiVoiceServiceProvider);
    if (voice == null) return; // صدا غیرفعال — بی‌اثر (Fail-safe)
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('aiTeacher.voiceNotRecognized'))));
        return;
      }
      await _sendText(text);
    } else {
      if (!await _recorder.hasPermission()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(context.tr('aiTeacher.micPermissionRequired'))));
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/ai_rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
      if (!mounted) return;
      setState(() => _isRecording = true);
    }
  }

  /// پخش پاسخ معلم AI با صدای خانم دری (TTS). دوباره‌فشردن = توقف.
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
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('curriculum.audioUnavailable'))));
      return;
    }
    await _player.play(DeviceFileSource(path));
  }

  /// دکمهٔ میکروفون — هنگام ضبط، با ضربان آرام و مدرن بزرگ/کوچک می‌شود تا
  /// وضعیت «در حال شنیدن» کاملاً واضح باشد.
  Widget _buildMicButton() {
    final button = IconButton(
      tooltip: _isRecording ? context.tr('aiTeacher.stopAndSend') : context.tr('aiTeacher.talkToTeacher'),
      icon: Icon(
        _isRecording ? Icons.stop_circle_rounded : Icons.mic_rounded,
        color: _isRecording ? Colors.red : null,
      ),
      onPressed: _sending ? null : _toggleRecord,
    );
    if (!_isRecording) return button;
    return button
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(end: 1.18, duration: 550.ms, curve: Curves.easeInOut);
  }

  Future<void> _sendCommand(String command) async {
    if (_sending) return;
    setState(() => _sending = true);
    await ref.read(aiConversationProvider(_subjectId).notifier).send(command);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiConversationProvider(_subjectId));
    final voiceEnabled = ref.watch(aiVoiceServiceProvider) != null;

    return AppScaffold(
      title: context.tr('aiTeacher.chatTitle', {'subject': _subject.nameFa}),
      role: AppUserRole.student,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.swap_horiz),
          onSelected: (id) => setState(() => _subjectId = id),
          itemBuilder: (context) => mockSubjects
              .map((s) => PopupMenuItem(value: s.id, child: Text(s.nameFa)))
              .toList(),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (i >= messages.length) {
                  final scheme = Theme.of(context).colorScheme;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            gradient: AppColors.sunriseGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainer,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(AppRadii.md),
                              topRight: Radius.circular(AppRadii.md),
                              bottomLeft: Radius.circular(4),
                              bottomRight: Radius.circular(AppRadii.md),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var d = 0; d < 3; d++)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: EdgeInsets.only(left: d == 2 ? 0 : 5),
                                  decoration: BoxDecoration(
                                    color: scheme.onSurfaceVariant,
                                    shape: BoxShape.circle,
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat())
                                    .fadeIn(delay: (150 * d).ms, duration: 400.ms)
                                    .then()
                                    .fadeOut(delay: 200.ms, duration: 400.ms),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 200.ms);
                }
                final msg = messages[i];
                final isAi = msg.sender == ChatSender.ai;
                final scheme = Theme.of(context).colorScheme;
                final isLast = i == messages.length - 1;
                final bubble = Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isAi) ...[
                        Container(
                          width: 30,
                          height: 30,
                          margin: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            gradient: AppColors.sunriseGradient,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.smart_toy_rounded, size: 16, color: Colors.white),
                        ),
                      ],
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                          decoration: BoxDecoration(
                            gradient: isAi ? null : AppColors.heroGradient,
                            color: isAi ? scheme.surfaceContainer : null,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(AppRadii.md),
                              topRight: const Radius.circular(AppRadii.md),
                              bottomLeft: Radius.circular(isAi ? 4 : AppRadii.md),
                              bottomRight: Radius.circular(isAi ? AppRadii.md : 4),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(msg.body, style: TextStyle(color: isAi ? scheme.onSurface : Colors.white)),
                              if (msg.sourceReference != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  context.tr('aiTeacher.sourceReference', {'reference': msg.sourceReference!}),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isAi ? scheme.onSurfaceVariant : Colors.white70,
                                  ),
                                ),
                              ],
                              // ── شنیدن پاسخ با صدای خانم دری (TTS، Fail-safe) ──
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
                                        style: TextStyle(fontSize: 11, color: scheme.primary),
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
                if (!isLast) return bubble;
                return bubble
                    .animate()
                    .fadeIn(duration: 240.ms, curve: Curves.easeOut)
                    .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(context.tr('aiTeacher.nextSection')),
                    onPressed: _sending ? null : () => _sendCommand(AiCommands.next),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.lightbulb_outline_rounded, size: 16),
                    label: Text(context.tr('aiTeacher.giveExample')),
                    onPressed: _sending ? null : () => _sendCommand(AiCommands.example),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.quiz_outlined, size: 16),
                    label: Text(context.tr('aiTeacher.requestExercise')),
                    onPressed: _sending ? null : () => _sendCommand(AiCommands.question),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          ),
          SafeArea(
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
                            : context.tr('aiTeacher.askQuestion'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // ── میکروفون: صحبت با معلم (STT، فقط در حالت Backend واقعی) ──
                  if (voiceEnabled)
                    _transcribing
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                          )
                        : _buildMicButton(),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: _sending ? null : _send,
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
