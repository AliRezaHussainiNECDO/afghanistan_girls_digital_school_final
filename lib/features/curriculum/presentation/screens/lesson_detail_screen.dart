import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../ai_teacher/presentation/providers/ai_teacher_providers.dart';
import '../../../ai_teacher/presentation/providers/learning_progress_providers.dart';
import '../../../ai_teacher/presentation/widgets/ai_voice_ask_sheet.dart';
import '../providers/curriculum_providers.dart';

/// نمایش یک درس — طبق بخش ۶.۲ (C1: viewed=true) و بخش ۴.۲ (رویداد
/// `POST /lessons/{id}/view` بلافاصله ارسال می‌شود، Backend صاحب حقیقت است).
///
/// صدا در نصاب تعلیمی (همهٔ مضامین، بخش ۲۱.۴ — ماژولار و Fail-safe):
///  • «شنیدن درس»: متن درس با صدای خانم دری (TTS) قطعه‌به‌قطعه پخش می‌شود.
///  • «پرسش از معلم»: شیت صوتی — میکروفون → STT → معلم AI همین مضمون → «شنیدن» پاسخ.
/// اگر Backend واقعی فعال نباشد، دکمه‌های صوتی نمایش داده نمی‌شوند.
class LessonDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final String lessonId;
  const LessonDetailScreen({super.key, required this.subjectId, required this.lessonId});

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  bool _marking = false;

  // ── «شنیدن درس» — پخش قطعه‌به‌قطعهٔ متن درس با TTS (Fail-safe) ──
  final _player = AudioPlayer();
  List<String> _ttsChunks = const [];
  int _ttsIndex = 0;
  bool _isReading = false; // در حال پخش یا آماده‌سازی
  bool _ttsLoading = false; // در حال دریافت قطعهٔ بعدی از سرور

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => _playNextChunk());
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  /// تقسیم متن درس به قطعه‌های کوتاه در مرز جمله‌ها (محدودیت طول TTS).
  static List<String> _splitForTts(String text, {int maxLen = 900}) {
    final sentences = text.split(RegExp(r'(?<=[.!?؟।۔\n])\s*'));
    final chunks = <String>[];
    final buf = StringBuffer();
    for (final s in sentences) {
      if (s.trim().isEmpty) continue;
      if (buf.length + s.length > maxLen && buf.isNotEmpty) {
        chunks.add(buf.toString());
        buf.clear();
      }
      buf.write('$s ');
    }
    if (buf.isNotEmpty) chunks.add(buf.toString());
    return chunks;
  }

  Future<void> _toggleReadLesson(String title, String body) async {
    final voice = ref.read(aiVoiceServiceProvider);
    if (voice == null) return; // صدا غیرفعال — بی‌اثر (Fail-safe)
    if (_isReading) {
      await _player.stop();
      setState(() {
        _isReading = false;
        _ttsLoading = false;
        _ttsChunks = const [];
        _ttsIndex = 0;
      });
      return;
    }
    setState(() {
      _isReading = true;
      _ttsChunks = _splitForTts('$title. $body');
      _ttsIndex = 0;
    });
    await _playNextChunk();
  }

  Future<void> _playNextChunk() async {
    if (!mounted || !_isReading) return;
    if (_ttsIndex >= _ttsChunks.length) {
      setState(() {
        _isReading = false;
        _ttsIndex = 0;
      });
      return;
    }
    final voice = ref.read(aiVoiceServiceProvider);
    if (voice == null) return;
    setState(() => _ttsLoading = true);
    final chunk = _ttsChunks[_ttsIndex];
    _ttsIndex += 1;
    final path = await voice.synthesize(chunk);
    if (!mounted || !_isReading) return;
    setState(() => _ttsLoading = false);
    if (path == null) {
      setState(() => _isReading = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پخش صوتی در حال حاضر در دسترس نیست.')));
      return;
    }
    await _player.play(DeviceFileSource(path));
  }

  /// باز کردن معلم هوشمند با مضمون همین درس (نه مضمون پیش‌فرض).
  void _openAiTeacher() {
    ref.read(aiTeacherInitialSubjectProvider.notifier).state = widget.subjectId;
    context.push(AppRoutes.aiTeacher);
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));
    final voiceEnabled = ref.watch(aiVoiceServiceProvider) != null;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('curriculum.viewLesson'))),
      // ── پرسش صوتی/متنی از معلم AI همین مضمون — در همهٔ مضامین نصاب ──
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'ask_ai_lesson',
        icon: Icon(voiceEnabled ? Icons.mic_rounded : Icons.smart_toy_rounded),
        label: const Text('پرسش از معلم'),
        onPressed: () => showAiVoiceAskSheet(context, widget.subjectId),
      ),
      body: lessonAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (lesson) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.heroGradient,
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  boxShadow: AppShadows.warm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.titleFa,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 14, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(
                          context.tr('curriculum.estimatedMinutes', {'minutes': '${lesson.estimatedMinutes}'}),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const Spacer(),
                        // ── شنیدن متن درس با صدای خانم دری (TTS، Fail-safe) ──
                        if (voiceEnabled)
                          _ttsLoading && _isReading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : InkWell(
                                  onTap: () =>
                                      _toggleReadLesson(lesson.titleFa, lesson.contentBody),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _isReading
                                            ? Icons.stop_circle_rounded
                                            : Icons.volume_up_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _isReading ? 'توقف' : 'شنیدن درس',
                                        style: const TextStyle(
                                            fontSize: 12, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: SingleChildScrollView(
                    child: Text(lesson.contentBody, style: Theme.of(context).textTheme.bodyLarge),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (!lesson.viewed)
                AppPrimaryButton(
                  label: context.tr('curriculum.viewLesson'),
                  loading: _marking,
                  icon: Icons.check_circle_outline_rounded,
                  onPressed: () async {
                    setState(() => _marking = true);
                    await ref.read(markLessonViewedUseCaseProvider).call(widget.lessonId);
                    ref.invalidate(lessonProvider(widget.lessonId));
                    if (mounted) setState(() => _marking = false);
                  },
                )
              else
                OutlinedButton.icon(
                  icon: const Icon(Icons.smart_toy_rounded),
                  label: Text(context.tr('nav.aiTeacher')),
                  onPressed: _openAiTeacher,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
