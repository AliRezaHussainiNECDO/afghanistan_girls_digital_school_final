import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../ai_teacher/presentation/providers/ai_teacher_providers.dart';
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
  /// ثبت خودکار «دیدن درس» به‌محض ورود (فقط یک‌بار) — طبق طرح «کلاس تعاملی»:
  /// دیگر دکمهٔ جداگانهٔ «مطالعه کردم» وجود ندارد؛ ورود به کلاس = دیدن درس.
  /// زنجیرهٔ خط قرمز (C1: viewed → امتیاز فعالیت → تکمیل فصل) دست‌نخورده
  /// همان Endpoint قبلی را صدا می‌زند؛ فقط کلیک اضافی حذف شده است.
  bool _autoViewStarted = false;

  void _autoMarkViewedOnce(Lesson lesson) {
    if (_autoViewStarted || lesson.viewed) return;
    _autoViewStarted = true;
    Future.microtask(() async {
      final result = await ref.read(markLessonViewedUseCaseProvider).call(widget.lessonId);
      ref.invalidate(lessonProvider(widget.lessonId));
      ref.invalidate(chaptersProvider(widget.subjectId));
      // خانهٔ شاگرد و نقشهٔ صنوف همین لحظه امتیاز/پیشرفت تازه را ببینند.
      final studentId = ref.read(authSessionProvider)?.id;
      if (studentId != null) {
        ref.invalidate(dashboardSummaryProvider(studentId));
        ref.invalidate(gradeMapProvider);
      }
      if (mounted) result.fold((_) {}, _showPointsFeedback);
    });
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

  /// «متن کامل درس» — دیگر صفحهٔ اصلی نیست (کلاس تعاملی جای آن را گرفته)،
  /// اما از آیکون 📖 در نوار بالای صفحه، هر لحظه به‌صورت شیت تمام‌قد در
  /// دسترس شاگرد می‌ماند تا اگر خواست خودش متن را مرور کند.
  void _showLessonTextSheet(Lesson lesson) {
    final scheme = Theme.of(context).colorScheme;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Directionality(
          textDirection: TextDirection.rtl,
          child: Markdown(
            controller: scrollController,
            data: lesson.contentBody,
            padding: const EdgeInsets.all(18),
            selectable: false,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 2.0,
                    letterSpacing: 0.1,
                    fontSize: 16.5,
                  ),
              h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
              h3: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              listBullet: Theme.of(context).textTheme.bodyLarge,
              blockquoteDecoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border(
                  right: BorderSide(color: scheme.primary, width: 3),
                ),
              ),
            ),
          ),
        ),
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
      // ── «کلاس تعاملی مبتنی بر گفت‌وگو» (طبق درخواست کاربر): شاگرد به‌محض
      // ورود مستقیماً وارد چت با معلم هوشمند همین درس می‌شود — نه متن خشک.
      appBar: AppBar(
        title: lessonAsync.maybeWhen(
          data: (lesson) => Text(
            '${context.tr('curriculum.askTeacher')} — ${lesson.titleFa}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          orElse: () => Text(context.tr('curriculum.askTeacher')),
        ),
        actions: lessonAsync.maybeWhen(
          data: (lesson) => [
            // «شنیدن درس» با صدای خانم دری (TTS، Fail-safe) — حفظ‌شده از قبل.
            if (voiceEnabled)
              _ttsLoading && _isReading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: _isReading
                          ? context.tr('curriculum.stopListening')
                          : context.tr('curriculum.listenLesson'),
                      icon: Icon(_isReading
                          ? Icons.stop_circle_rounded
                          : Icons.volume_up_rounded),
                      onPressed: () =>
                          _toggleReadLesson(lesson.titleFa, lesson.contentBody),
                    ),
            // «متن کامل درس» — هر وقت شاگرد خواست خودش بخواند.
            IconButton(
              tooltip: context.tr('curriculum.viewLesson'),
              icon: const Icon(Icons.menu_book_rounded),
              onPressed: () => _showLessonTextSheet(lesson),
            ),
          ],
          orElse: () => const [],
        ),
      ),
      body: lessonAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(error: e),
        data: (lesson) {
          // ثبت خودکار «دیدن درس» (زنجیرهٔ امتیاز/پیشرفت، فقط بار اول).
          _autoMarkViewedOnce(lesson);
          // چت معلم هوشمند = کل بدنهٔ صفحه؛ متن درس به‌عنوان زمینهٔ (Context)
          // قفل‌شده به سرور می‌رود، دکمهٔ «یاد گرفتم» و نوار «بخش X از Y» در
          // سرآیند خود کلاس قرار دارند (داخل AiVoiceAskSheet).
          return SafeArea(
            child: AiVoiceAskSheet(
              embedded: true,
              subjectId: widget.subjectId,
              lessonId: lesson.id,
              lessonTitle: lesson.titleFa,
              lessonContent: lesson.contentBody,
            ),
          );
        },
      ),
    );
  }
}
