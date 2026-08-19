import 'dart:async' show unawaited;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/tts_text_splitter.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../ai_teacher/presentation/providers/ai_teacher_providers.dart';
import '../../../ai_teacher/presentation/widgets/ai_voice_ask_sheet.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../competition/presentation/providers/competition_providers.dart';
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
      // رفع اشکال هماهنگی: بدون این خط، فهرست درس‌های همین فصل
      // (`lessonsProvider(chapterId)`) که «امروز» و LessonsScreen هر دو از
      // همان می‌خوانند، وضعیت «دیده‌شدهٔ» همین درس را تا پاک‌شدن کامل کش
      // (خروج از کل پشتهٔ ناوبری) کهنه نشان می‌داد.
      ref.invalidate(lessonsProvider(lesson.chapterId));
      // خانهٔ شاگرد و نقشهٔ صنوف همین لحظه امتیاز/پیشرفت تازه را ببینند.
      final studentId = ref.read(authSessionProvider)?.id;
      if (studentId != null) {
        ref.invalidate(dashboardSummaryProvider(studentId));
        ref.invalidate(gradeMapProvider);
      }
      // رفع اشکال (H6 — کهنه‌ماندنِ رقابت): دیدنِ درس هم امتیازِ فعالیت
      // می‌دهد (و می‌تواند فصل را هم تکمیل کند) — صفحهٔ رقابت/جدولِ
      // امتیازات باید همین لحظه تازه شود، نه فقط با claim کردنِ میشن‌ها.
      ref.read(competitionRefreshProvider.notifier).state++;
      if (mounted) {
        result.fold((_) {}, (r) {
          _showPointsFeedback(r);
          // «آزمون فصل» خودکار (طبق درخواست صاحب پروژه): وقتی همین درس فصل را
          // تکمیل کرد، بعد از چند لحظه (تا جشن امتیاز دیده شود) شاگرد را به
          // آزمون فصل هدایت می‌کنیم — سرور در پس‌زمینه همین الان با AI سؤالات
          // را می‌سازد (backend/src/routes/curriculum.ts::/lessons/:id/view).
          if (r.chapterJustCompleted) {
            Future.delayed(const Duration(milliseconds: 1400), () {
              if (mounted) {
                context.push(AppRoutes.chapterQuiz(widget.subjectId, lesson.chapterId));
              }
            });
          }
        });
      }
    });
  }

  // ── «شنیدن درس» — پخش قطعه‌به‌قطعهٔ متن درس با TTS (Fail-safe) ──
  final _player = AudioPlayer();
  List<String> _ttsChunks = const [];
  int _ttsIndex = 0;
  bool _isReading = false; // در حال پخش یا آماده‌سازی
  bool _ttsLoading = false; // در حال دریافت قطعهٔ بعدی از سرور
  bool _ttsAnyChunkPlayed = false; // آیا در همین جلسهٔ خواندن، حداقل یک قطعه با موفقیت پخش شده

  // رفعِ اشکالِ گزارش‌شده («صدا چند لحظه معطل می‌ماند تا پلی شود، خسته‌کننده
  // است»): قبلاً هر قطعه فقط *بعد از* اینکه قطعهٔ قبلی کاملاً تمام می‌شد
  // ساخته می‌شد (پخش → onComplete → ساختِ قطعهٔ بعدی → پخش) — یعنی شاگرد
  // بینِ هر دو قطعهٔ پیاپی، دقیقاً به‌اندازهٔ زمانِ کاملِ تولیدِ صدای سرور
  // (چند ثانیه) در سکوت می‌ماند. حالا هر قطعه فقط یک‌بار ساخته می‌شود (نتیجه
  // در همین Map کش می‌شود) و همین‌که پخشِ یک قطعه *شروع* شد، بلافاصله ساختِ
  // قطعهٔ بعدی هم در پس‌زمینه آغاز می‌شود — تا وقتی قطعهٔ فعلی تمام شود،
  // قطعهٔ بعدی معمولاً از قبل آماده است و هیچ سکوتی حس نمی‌شود. علاوه‌براین،
  // اولین قطعه از همان لحظه‌ای که خودِ درس لود می‌شود (نه از لحظهٔ زدنِ دکمهٔ
  // پخش) در پس‌زمینه پیش‌بارگذاری می‌شود — نگاه کنید به `_prefetchListenAudioOnce`.
  final Map<int, Future<String?>> _ttsChunkFutures = {};
  bool _ttsPrefetchStarted = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) => _playChunkAt(_ttsIndex));
  }

  /// یک‌بار، همین که متنِ درس آماده شد (قبل از اینکه شاگرد اصلاً دکمهٔ
  /// «شنیدنِ درس» را بزند)، ساختِ صدای قطعهٔ *اول* را در پس‌زمینه آغاز
  /// می‌کند — تا اگر شاگرد بخواهد گوش بدهد، معمولاً بدونِ هیچ معطلی
  /// بلافاصله پخش شود. هزینهٔ این کار عمداً کم نگه داشته شده: فقط یک قطعهٔ
  /// کوچک (حداکثر ۴۵۰ حرف)، نه کلِ درس — بقیهٔ قطعات فقط اگر شاگرد واقعاً
  /// «شنیدن» را زد ساخته می‌شوند (پایین‌تر، به‌صورت پیوسته حینِ پخش).
  void _prefetchListenAudioOnce(String title, String body) {
    if (_ttsPrefetchStarted) return;
    if (ref.read(aiVoiceServiceProvider) == null) return; // صدا غیرفعال — بی‌اثر
    _ttsPrefetchStarted = true;
    _ttsChunks = splitForTts('$title. $body');
    _ensureChunkFuture(0);
  }

  /// تولیدِ صدای یک قطعه با تلاشِ مجدد (تا ۲ بارِ دیگر، با مکثِ فزاینده) —
  /// دقیقاً همان قاعدهٔ قبلی، فقط حالا در قالبِ یک Future قابلِ‌کش تا هم
  /// پیش‌بارگذاری و هم پخشِ واقعی بتوانند به همان یک نتیجه برسند بدونِ
  /// دوبار-درخواست‌دادن.
  Future<String?> _synthesizeWithRetry(String chunk, {int attempt = 0}) async {
    final voice = ref.read(aiVoiceServiceProvider);
    if (voice == null) return null;
    final path = await voice.synthesize(chunk);
    if (path != null || attempt >= 2) return path;
    await Future.delayed(Duration(milliseconds: 700 * (attempt + 1)));
    return _synthesizeWithRetry(chunk, attempt: attempt + 1);
  }

  /// اگر ساختِ صدای قطعهٔ [index] قبلاً آغاز نشده، همین حالا (در پس‌زمینه)
  /// آغازش می‌کند و Future مشترک را برمی‌گرداند — فراخوانی‌های بعدی برای
  /// همان اندیس، به همان یک Future وصل می‌شوند (نه یک درخواستِ تازه).
  Future<String?> _ensureChunkFuture(int index) {
    if (index < 0 || index >= _ttsChunks.length) return Future.value(null);
    return _ttsChunkFutures.putIfAbsent(index, () => _synthesizeWithRetry(_ttsChunks[index]));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // تقسیمِ متنِ درس به قطعه‌های کوتاه، طبقِ «قاعدهٔ تضمینیِ» مشترکِ
  // core/utils/tts_text_splitter.dart (نگاه کنید آنجا برای تاریخچهٔ کامل
  // رفع اشکال — این منطق حالا بینِ این صفحه و AiVoiceAskSheet مشترک است تا
  // هر دو مسیرِ «شنیدنِ صدا» در اپ همیشه یک قاعده را رعایت کنند).

  Future<void> _toggleReadLesson(String title, String body) async {
    final voice = ref.read(aiVoiceServiceProvider);
    if (voice == null) return; // صدا غیرفعال — بی‌اثر (Fail-safe)
    if (_isReading) {
      await _player.stop();
      setState(() {
        _isReading = false;
        _ttsLoading = false;
        _ttsIndex = 0;
      });
      return;
    }
    // معمولاً `_ttsChunks`/قطعهٔ اول از قبل با `_prefetchListenAudioOnce`
    // ساخته شده‌اند (همان لحظه‌ای که خودِ درس لود شد)؛ این فقط Fail-safe
    // برای حالتِ نادری است که هنوز آغاز نشده باشد (مثلاً پیش‌بارگذاری با
    // خطا مواجه شده بود).
    if (_ttsChunks.isEmpty) {
      _ttsChunks = splitForTts('$title. $body');
    }
    setState(() {
      _isReading = true;
      _ttsAnyChunkPlayed = false;
      _ttsIndex = 0;
    });
    await _playChunkAt(0);
  }

  /// رفع اشکال ریشه‌ای «هرچه درسِ طولانی‌تر، احتمال بیشترِ قطع‌شدنِ کاملِ
  /// صدا»: یک درسِ طولانی به چند ده قطعهٔ پیاپی تبدیل می‌شود (بعد از رفعِ
  /// اشکالِ قبلیِ اندازهٔ قطعه‌ها). قبلاً اگر فقط **یکی** از این درخواست‌های
  /// پیاپی به هر دلیلِ گذرا (یک نوسانِ لحظه‌ایِ شبکهٔ موبایل، نه یک خرابیِ
  /// واقعی سرویس) شکست می‌خورد، کل جلسهٔ «شنیدنِ درس» بی‌بازگشت متوقف می‌شد و
  /// پیام عمومیِ «در دسترس نیست» نشان داده می‌شد — یعنی هرچه درس طولانی‌تر
  /// (پس تعداد درخواست‌های پیاپی بیشتر)، احتمالِ برخوردن به همین یک شکستِ
  /// گذرا در جایی وسطِ درس ریاضی‌وار بیشتر می‌شد؛ این خودش، مستقل از هر
  /// Timeout یا اندازهٔ قطعه، دقیقاً همان الگوی گزارش‌شده («درس‌های طولانی‌تر
  /// پخش نمی‌شوند») را توضیح می‌دهد.
  ///
  /// قاعدهٔ تضمینیِ (بدونِ وابستگی به این‌که هر تک‌درخواست حتماً موفق شود):
  /// ساختِ هر قطعه — با تلاشِ مجدد — داخلِ `_synthesizeWithRetry`/
  /// `_ensureChunkFuture` بالا انجام می‌شود. اگر همان یک قطعهٔ خاص بعد از
  /// همهٔ تلاش‌ها هم شکست خورد، *فقط همان قطعه* رد می‌شود و به قطعهٔ بعدی
  /// می‌رویم — نه این‌که کل تجربهٔ شنیدنِ درس را به‌خاطر یک بخشِ کوچک خراب
  /// کنیم. پیامِ «در دسترس نیست» فقط زمانی نشان داده می‌شود که حتی اولین
  /// قطعه هم (بعد از تلاش‌های تکراری) شکست بخورد — یعنی وقتی مشکل واقعاً
  /// کلی/سیستمی است (مثلاً اصلاً اینترنت نیست)، نه یک نوسانِ لحظه‌ای وسط
  /// یک درسِ در حال پخش.
  ///
  /// رفعِ اشکالِ «صدا معطل می‌ماند» (بالای فایل، کنارِ `_ttsChunkFutures`):
  /// این متد صبر می‌کند تا صدای قطعهٔ [index] آماده شود (که معمولاً از قبل،
  /// در پس‌زمینه، یا با پخشِ قطعهٔ قبلی هم‌زمان، شروع به ساختن شده)، و درست
  /// همین‌که پخش را آغاز می‌کند، بلافاصله ساختِ قطعهٔ *بعدی* را هم در
  /// پس‌زمینه شروع می‌کند — بدونِ صبر کردن برای تمام‌شدنِ پخشِ فعلی.
  Future<void> _playChunkAt(int index) async {
    if (!mounted || !_isReading) return;
    if (index >= _ttsChunks.length) {
      setState(() {
        _isReading = false;
        _ttsIndex = 0;
      });
      return;
    }
    setState(() => _ttsLoading = true);
    final path = await _ensureChunkFuture(index);
    if (!mounted || !_isReading) return;
    if (path == null) {
      // این قطعهٔ خاص بعد از چند تلاشِ داخلیِ `_synthesizeWithRetry` هم جواب نداد.
      if (!_ttsAnyChunkPlayed) {
        // حتی یک قطعه هم تا الان پخش نشده — مشکل احتمالاً کلی/سیستمی است،
        // نه یک نوسانِ گذرای وسطِ درس؛ اینجا واقعاً باید به کاربر خبر داد.
        setState(() {
          _isReading = false;
          _ttsLoading = false;
        });
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.tr('curriculum.audioUnavailable'))));
        }
        return;
      }
      // بخشی از درس قبلاً با موفقیت پخش شده — همین یک قطعه را رد کن و ادامه بده.
      setState(() => _ttsIndex = index + 1);
      return _playChunkAt(index + 1);
    }
    setState(() {
      _ttsAnyChunkPlayed = true;
      _ttsIndex = index + 1;
      _ttsLoading = false;
    });
    // پیش‌بارگذاریِ قطعهٔ بعدی هم‌زمان با شروعِ پخشِ همین قطعه — نه بعد از
    // تمام‌شدنِ آن — تا وقتی نوبتِ آن برسد، معمولاً از قبل آماده باشد.
    unawaited(_ensureChunkFuture(index + 1));
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
          child: Column(
            children: [
              // نصاب چندزبانه: وقتی زبان اپ غیر دری است ولی متن این درس هنوز
              // ترجمه نشده، یک نوار کوچک بالای متن دری Fallback را مشخص می‌کند
              // (طبق درخواست صاحب پروژه — به‌جای صفحهٔ خالی یا گیج‌کننده).
              if (!lesson.translated)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded, size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          context.tr('curriculum.notYetTranslated'),
                          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
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
            ],
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
        // رفع اشکالِ «درس یافت نشد، ولی معلوم نیست چرا/از کجا»: قبلاً این حالت
        // فقط یک ErrorView با «تلاش دوباره» نشان می‌داد — اما اگر lessonId
        // واقعاً دیگر روی سرور وجود نداشته باشد (مثلاً حذف/بازسازیِ نصاب،
        // یا یک اشارهٔ نامعتبر از یک مسیر ناوبریِ دیگر مثل «برنامهٔ درسی
        // امروز»)، تلاشِ دوباره هم همیشه همان خطا را می‌دهد و دانش‌آموز در
        // یک بن‌بست گیر می‌کرد. حالا دو کار اضافه شده: ۱) این خطا (همراه
        // subjectId/lessonId دقیق) در «گزارش خطاهای برنامه» (پنل مدیر) ثبت
        // می‌شود تا اگر باز هم رخ داد، بشود دقیقاً دید کدام مسیر ناوبری این
        // شناسهٔ نامعتبر را ساخته؛ ۲) یک دکمهٔ «بازگشت به فهرست دروس» اضافه
        // شد تا دانش‌آموز هرگز در بن‌بست نماند.
        error: (e, st) {
          AppErrorHandler.record(
            e,
            st,
            context: 'LessonDetail.load subjectId=${widget.subjectId} lessonId=${widget.lessonId}',
          );
          return Column(
            children: [
              Expanded(
                child: ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(lessonProvider(widget.lessonId)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.curriculumChapters(widget.subjectId)),
                    icon: const Icon(Icons.list_alt_rounded, size: 18),
                    label: Text(context.tr('curriculum.backToLessonList')),
                  ),
                ),
              ),
            ],
          );
        },
        data: (lesson) {
          // ثبت خودکار «دیدن درس» (زنجیرهٔ امتیاز/پیشرفت، فقط بار اول).
          _autoMarkViewedOnce(lesson);
          // پیش‌بارگذاریِ صدای قطعهٔ اول در پس‌زمینه (رفعِ اشکالِ «صدا معطل
          // می‌ماند») — فقط یک‌بار، همین که متنِ درس آماده شد.
          _prefetchListenAudioOnce(lesson.titleFa, lesson.contentBody);
          // چت معلم هوشمند = کل بدنهٔ صفحه؛ متن درس به‌عنوان زمینهٔ (Context)
          // قفل‌شده به سرور می‌رود، دکمهٔ «یاد گرفتم» و نوار «بخش X از Y» در
          // سرآیند خود کلاس قرار دارند (داخل AiVoiceAskSheet).
          return SafeArea(
            child: AiVoiceAskSheet(
              embedded: true,
              subjectId: widget.subjectId,
              chapterId: lesson.chapterId,
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
