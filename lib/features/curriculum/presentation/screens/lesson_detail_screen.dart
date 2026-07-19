import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../grade_map/presentation/providers/grade_map_providers.dart';
import '../../../student_dashboard/presentation/providers/dashboard_providers.dart';
import '../../domain/entities/curriculum_entities.dart';
import '../providers/curriculum_providers.dart';

/// نمایش یک درس — طبق بخش ۶.۲ (C1: viewed=true) و بخش ۴.۲ (رویداد
/// `POST /lessons/{id}/view` بلافاصله ارسال می‌شود، Backend صاحب حقیقت است).
///
/// صدا در نصاب تعلیمی (همهٔ مضامین، بخش ۲۱.۴ — ماژولار و Fail-safe):
///  • «شنیدن درس»: متن درس با صدای خانم دری (TTS) قطعه‌به‌قطعه پخش می‌شود.
///  • «پرسش از معلم»: شیت صوتی — میکروفون → STT → معلم AI همین مضمون → «شنیدن» پاسخ.
/// اگر Backend واقعی فعال نباشد، دکمه‌های صوتی نمایش داده نمی‌شوند.
///
/// همچنین امتیاز فعالیت (Gamification) را بلافاصله بعد از دیدن درس نمایش
/// می‌دهد — اگر همین درس آخرین درسِ فصل بود، جشن تکمیل فصل هم نشان داده
/// می‌شود (پایهٔ باز شدن خودکار فصل بعدی، `backend/src/lib/progress.ts`).
class LessonDetailScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final String lessonId;
  const LessonDetailScreen({super.key, required this.subjectId, required this.lessonId});

  @override
  ConsumerState<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends ConsumerState<LessonDetailScreen> {
  bool _marking = false;

  /// «این درس را یاد گرفتم» — کار خانگی فقط با زدن همین دکمه ساخته می‌شود
  /// (نه خودکار با باز کردن درس)؛ برای هر درس فقط یک‌بار (سرور idempotent).
  bool _learning = false;
  bool _learnedThisSession = false;

  Future<void> _markLearned() async {
    if (_learning) return;
    setState(() => _learning = true);
    final result = await ref.read(markLessonLearnedUseCaseProvider).call(widget.lessonId);
    if (!mounted) return;
    setState(() => _learning = false);
    final messenger = ScaffoldMessenger.of(context);
    result.fold(
      (f) => messenger.showSnackBar(
          SnackBar(content: Text(context.tr('curriculum.homeworkAssignFailed')))),
      (r) {
        setState(() => _learnedThisSession = true);
        messenger.showSnackBar(SnackBar(
            content: Text(r.assigned
                ? context.tr('curriculum.homeworkAssigned')
                : r.alreadyAssigned
                    ? context.tr('curriculum.homeworkAlreadyAssigned')
                    : context.tr('curriculum.homeworkAssignFailed'))));
      },
    );
  }

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
          SnackBar(content: Text(context.tr('curriculum.audioUnavailable'))));
      return;
    }
    await _player.play(DeviceFileSource(path));
  }

  /// باز کردن معلم هوشمند با مضمون همین درس (نه مضمون پیش‌فرض).
  void _openAiTeacher() {
    ref.read(aiTeacherInitialSubjectProvider.notifier).state = widget.subjectId;
    context.push(AppRoutes.aiTeacher);
  }

  /// بازخورد فوری امتیاز فعالیت — بعد از دیدن درس نشان داده می‌شود؛ اگر همین
  /// درس فصل را تکمیل کرده باشد، بنر جشنِ بزرگ‌تری (با گرادیان طلایی) دیده
  /// می‌شود تا شاگرد را برای رفتن به فصل بعدی تشویق کند.
  void _showPointsFeedback(LessonViewResult result) {
    if (result.totalPointsThisAction <= 0) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        duration: Duration(seconds: result.chapterJustCompleted ? 4 : 2),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: result.chapterJustCompleted ? AppColors.sunriseGradient : AppColors.successGradient,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppShadows.green,
          ),
          child: Row(
            children: [
              Icon(
                result.chapterJustCompleted ? Icons.emoji_events_rounded : Icons.star_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      result.chapterJustCompleted
                          ? context.tr('curriculum.chapterCompletedCelebration')
                          : context.tr('curriculum.wellDoneExclaim'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    Text(
                      result.chapterJustCompleted
                          ? context.tr('curriculum.pointsChapterCompleted', {
                              'points': '${result.pointsAwarded}',
                              'bonus': '${result.chapterBonusAwarded}',
                            })
                          : context.tr('curriculum.pointsEarned', {'points': '${result.pointsAwarded}'}),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));
    final voiceEnabled = ref.watch(aiVoiceServiceProvider) != null;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('curriculum.viewLesson'))),
      // ── پرسش صوتی/متنی از معلم AI — متمرکز روی دقیقاً همین درس، در همهٔ
      // مضامین و صنف‌های نصاب (طبق درخواست کاربر) ──
      floatingActionButton: lessonAsync.maybeWhen(
        data: (lesson) => FloatingActionButton.extended(
          heroTag: 'ask_ai_lesson',
          icon: Icon(voiceEnabled ? Icons.mic_rounded : Icons.smart_toy_rounded),
          label: Text(context.tr('curriculum.askTeacher')),
          onPressed: () => showAiVoiceAskSheet(
            context,
            subjectId: widget.subjectId,
            lessonId: lesson.id,
            lessonTitle: lesson.titleFa,
            lessonContent: lesson.contentBody,
          ),
        ),
        orElse: () => null,
      ),
      body: lessonAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
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
                                        _isReading
                                            ? context.tr('curriculum.stopListening')
                                            : context.tr('curriculum.listenLesson'),
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
                    child: Text(
                      lesson.contentBody,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            height: 2.0,
                            letterSpacing: 0.1,
                            fontSize: 16.5,
                          ),
                    ),
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
                    final result =
                        await ref.read(markLessonViewedUseCaseProvider).call(widget.lessonId);
                    ref.invalidate(lessonProvider(widget.lessonId));
                    ref.invalidate(chaptersProvider(widget.subjectId));
                    // رفع اشکال «پیشرفت/امتیاز خانهٔ شاگرد به‌روز نمی‌شود»:
                    // دیدن این درس ممکن است امتیاز فعالیت داده باشد (و اگر
                    // فصل را هم تمام کرده، امتیاز فصل + پیشرفت کلی هم تغییر
                    // کرده) — خانهٔ شاگرد و نقشهٔ صنوف باید همین لحظه آن را
                    // ببینند، نه فقط دفعهٔ بعد که برنامه از نو باز شود.
                    final studentId = ref.read(authSessionProvider)?.id;
                    if (studentId != null) {
                      ref.invalidate(dashboardSummaryProvider(studentId));
                      // نقشهٔ صنوف اکنون به‌ازای هر صنف جدا کش می‌شود؛ ساده‌ترین
                      // و امن‌ترین راه، باطل‌کردن کل خانوادهٔ Provider است.
                      ref.invalidate(gradeMapProvider);
                    }
                    if (mounted) {
                      setState(() => _marking = false);
                      result.fold((_) {}, _showPointsFeedback);
                    }
                  },
                )
              else ...[
                // «این درس را یاد گرفتم» — بعد از خواندن درس، شاگرد خودش
                // اعلام می‌کند تا کار خانگیِ همین درس (فقط یک‌بار) ساخته شود.
                AppPrimaryButton(
                  label: context.tr('curriculum.lessonLearnedButton'),
                  loading: _learning,
                  icon: _learnedThisSession ? Icons.check_circle_rounded : Icons.school_rounded,
                  onPressed: _learnedThisSession ? null : _markLearned,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.smart_toy_rounded),
                  label: Text(context.tr('nav.aiTeacher')),
                  onPressed: _openAiTeacher,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
