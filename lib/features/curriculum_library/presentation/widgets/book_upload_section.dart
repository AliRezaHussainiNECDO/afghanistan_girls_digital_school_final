import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../domain/entities/curriculum_book.dart';
import '../../domain/services/chapter_detector.dart';
import '../../domain/usecases/curriculum_library_usecases.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../providers/curriculum_library_providers.dart';
import '../screens/lesson_editor_screen.dart';

/// هر جا کتابخانهٔ نصاب تغییر می‌کند (آپلود/حذف/انتشار فصل/بازسازی)،
/// کش نصاب شاگردان هم باید همراه آن باطل شود — وگرنه شاگردی که همین صفحه
/// را همان لحظه باز دارد (مثلاً پیش‌نمایش مدیر) دیتای قدیمی می‌بیند.
void _invalidateStudentCurriculumCaches(WidgetRef ref) {
  ref.invalidate(chaptersProvider);
  ref.invalidate(lessonsProvider);
  ref.invalidate(lessonProvider);
}

/// بخش «کتاب‌های نصاب تعلیمی» برای هر مضمون — مدیر از این‌جا کتاب پی‌دی‌اف
/// رسمی وزارت معارف را برای هر صنف (۷ الی ۱۲) به‌طور جداگانه آپلود می‌کند؛
/// طبق نصاب رسمی هر صنف کتاب مستقل خودش را دارد، پس معلم هوشمند باید بتواند
/// دقیقاً از روی کتاب همان صنف شاگرد تدریس کند (طبق درخواست صریح کاربر).
/// متن هر کتاب به‌صورت محلی استخراج می‌شود و پایهٔ تدریس واقعی می‌گردد.
///
/// همچنین بلافاصله بعد از آپلود، عنوان‌های فصل کتاب با [ChapterDetector]
/// به‌صورت هوشمند شناسایی و (در صورت اطمینان کافی) به Backend منتشر می‌شوند
/// تا فصل‌بندی/قفل‌گشایی ترتیبی واقعی برای شاگردان همین مضمون فعال شود
/// (طبق درخواست کاربر: «شناسایی هوشمندانه عناوین فصل کتاب»).
class BookUploadSection extends ConsumerWidget {
  final String subjectId;
  final String subjectNameFa;

  const BookUploadSection({super.key, required this.subjectId, required this.subjectNameFa});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final booksAsync = ref.watch(booksForSubjectProvider(subjectId));

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(context.tr('curriculumBook.sectionTitle', {'subject': subjectNameFa}),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          booksAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
            error: (e, st) => Text(context.tr('curriculumBook.errorPrefix', {'error': '$e'}), style: TextStyle(color: scheme.error, fontSize: 12)),
            data: (books) {
              final byGrade = <int, CurriculumBook>{
                for (final b in books.where((b) => AppConstants.grades.contains(b.gradeId))) b.gradeId: b,
              };
              return Column(
                children: AppConstants.grades
                    .map((grade) => _GradeBookRow(
                          subjectId: subjectId,
                          subjectNameFa: subjectNameFa,
                          grade: grade,
                          book: byGrade[grade],
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _GradeBookRow extends ConsumerStatefulWidget {
  final String subjectId;
  final String subjectNameFa;
  final int grade;
  final CurriculumBook? book;

  const _GradeBookRow({
    required this.subjectId,
    required this.subjectNameFa,
    required this.grade,
    required this.book,
  });

  @override
  ConsumerState<_GradeBookRow> createState() => _GradeBookRowState();
}

class _GradeBookRowState extends ConsumerState<_GradeBookRow>
    with SingleTickerProviderStateMixin {
  bool _extracting = false;
  String? _extractError;

  /// در حال بازسازی دستی نصاب برای کتابی که قبلاً آپلود شده (دکمهٔ «بازسازی
  /// نصاب» روی ردیف‌های بدون فصل) — مستقل از `_extracting` چون نیازی به
  /// انتخاب دوبارهٔ فایل PDF نیست.
  bool _rebuilding = false;

  /// پیام موفقیت شناسایی فصل — بعد از آپلود موفق نشان داده می‌شود، مثل
  /// «۸ فصل شناسایی و منتشر شد» یا نمایش این‌که فصل‌بندی خودکار ممکن نشد.
  String? _chapterInfo;

  /// پیام موفقیت‌آمیز بودن خود آپلود (مستقل از فصل‌بندی) — چند ثانیه بعد
  /// از پایان آپلود به‌صورت خودکار محو می‌شود.
  bool _showSuccess = false;
  Duration _lastUploadDuration = Duration.zero;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _tickTimer;
  Timer? _successHideTimer;

  /// انیمیشن ضربان‌دار برای آیکن آپلود در حین پردازش — جلوه‌ای زنده و مدرن.
  ///
  /// نکته: عمداً در [initState] (نه به‌صورت lazy `late final` با مقداردهی در
  /// محل تعریف فیلد) ساخته می‌شود. اگر این ردیف هرگز وارد حالت `_extracting`
  /// نشود، فیلد lazy تا لحظهٔ اجرای `dispose()` هرگز خوانده نمی‌شد؛ در آن
  /// لحظه سازندهٔ `AnimationController(vsync: this, ...)` بار اول اجرا
  /// می‌شد و چون ویجت already deactivated است، جست‌وجوی TickerMode از
  /// درخت والد با خطای «Looking up a deactivated widget's ancestor is
  /// unsafe» کرش می‌کرد. ساخت زودهنگام در initState این مشکل را ریشه‌ای
  /// حل می‌کند.
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _successHideTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startProgressClock() {
    _stopwatch
      ..reset()
      ..start();
    _tickTimer?.cancel();
    _tickTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      if (mounted) setState(() {});
    });
  }

  void _stopProgressClock() {
    _tickTimer?.cancel();
    _tickTimer = null;
    _stopwatch.stop();
  }

  String get _elapsedLabel => context.tr('curriculumBook.secondsSuffix',
      {'seconds': (_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)});

  Future<void> _pickAndUpload() async {
    setState(() {
      _extractError = null;
      _chapterInfo = null;
      _showSuccess = false;
    });
    _successHideTimer?.cancel();
    FilePickerResult? result;
    try {
      // اصلاح متد برای سازگاری با نسخه‌های جدید و رفع خطای Member not found
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
    } catch (e) {
      if (mounted) setState(() => _extractError = context.tr('curriculumBook.filePickFailed', {'error': '$e'}));
      return;
    }
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _extractError = context.tr('curriculumBook.fileReadFailed'));
      return;
    }

    setState(() => _extracting = true);
    _startProgressClock();
    try {
      final document = PdfDocument(inputBytes: bytes);
      final pageCount = document.pages.count;

      // ── متن کامل + شناسایی فصل، هر دو از همان خطوط مرتب‌شدهٔ هندسی ──
      // پیش‌تر متن کامل با `extractText()` ساده گرفته می‌شد که برای برخی
      // PDFهای دری/پشتو ترتیب خط‌ها را جابه‌جا برمی‌گرداند (رفع اشکال «متن
      // نامنظم» در مشاهدهٔ درس). حالا هر دو از `ChapterDetector.extractOrderedLines`
      // (مرتب‌شده بر اساس صفحه/موقعیت عمودی) ساخته می‌شوند تا هرگز با هم
      // ناهماهنگ نباشند.
      String text = '';
      List<DetectedChapter> detectedChapters = const [];
      try {
        final lines = ChapterDetector.extractOrderedLines(document);
        text = lines.map((l) => l.text.trim()).where((t) => t.isNotEmpty).join('\n');
        detectedChapters = ChapterDetector.detectFromLines(lines);
      } catch (_) {
        detectedChapters = const []; // Fail-safe: شکست تشخیص فصل نباید آپلود را متوقف کند
      }
      if (text.trim().isEmpty) {
        // آخرین راه‌حل — اگر استخراج مرتب‌شده هم چیزی نداد.
        try {
          text = PdfTextExtractor(document).extractText();
        } catch (_) {}
      }
      document.dispose();

      if (text.trim().isEmpty) {
        setState(() {
          _extracting = false;
          _extractError = context.tr('curriculumBook.noTextExtracted');
        });
        return;
      }

      final title = file.name.replaceAll('.pdf', '');
      final addResult = await ref.read(addBookUseCaseProvider).call(AddBookParams(
            subjectId: widget.subjectId,
            title: title,
            pageCount: pageCount,
            gradeId: widget.grade,
            extractedText: text,
          ));
      ref.invalidate(booksForSubjectProvider(widget.subjectId));
      _invalidateStudentCurriculumCaches(ref);

      // ── انتشار فصل‌ها و درس‌های شناسایی‌شده — تضمین می‌کند نصاب شاگردان هرگز
      // به‌خاطر شکست یک هیوریستیک خالی نماند:
      //   ۱) اگر کلاینت با اطمینان کافی (≥۲ فصل) تشخیص داده، همان مسیر سریع
      //      قبلی طی می‌شود.
      //   ۲) در غیر آن صورت (یا اگر همان مسیر شکست خورد)، ساختاربندی خودکار
      //      سمت سرور از روی متن کامل ذخیره‌شدهٔ کتاب صدا زده می‌شود — این
      //      مسیر همیشه چیزی تولید می‌کند، پس هرگز بی‌صدا رها نمی‌شویم.
      await addResult.fold((_) async {}, (book) async {
        if (!kUseLiveBackend) {
          if (mounted) {
            setState(() => _chapterInfo = context.tr('curriculumBook.localModeChapterNotice'));
          }
          return;
        }
        if (detectedChapters.length >= 2) {
          final lessonCount = detectedChapters.fold<int>(0, (sum, c) => sum + c.lessons.length);
          try {
            await ref.read(apiClientProvider).post(
              '/admin/curriculum/subjects/${widget.subjectId}/publish-chapters',
              data: {
                'bookId': book.id,
                'gradeId': widget.grade,
                'chapters': detectedChapters
                    .map((c) => {
                          'title': c.title,
                          'lessons': c.lessons
                              .map((l) => {'title': l.title, 'content': l.content})
                              .toList(),
                        })
                    .toList(),
              },
            );
            if (mounted) {
              setState(() => _chapterInfo = context.tr('curriculumBook.chaptersDetectedPublished',
                  {'chapters': '${detectedChapters.length}', 'lessons': '$lessonCount'}));
            }
            ref.invalidate(booksForSubjectProvider(widget.subjectId));
      _invalidateStudentCurriculumCaches(ref);
            return;
          } catch (_) {
            // مسیر مبتنی بر تشخیص کلاینت شکست خورد → به مسیر ایمن سرور می‌رویم.
          }
        }
        await _autoStructureOnServer(book.id, isFallback: true);
      });

      if (mounted) {
        _lastUploadDuration = _stopwatch.elapsed;
        setState(() {
          _extracting = false;
          _showSuccess = true;
        });
        _successHideTimer?.cancel();
        _successHideTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _showSuccess = false);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _extractError = context.tr('curriculumBook.pdfProcessErrorWithReason', {'error': '$e'});
      });
    } finally {
      _stopProgressClock();
    }
  }

  Future<void> _delete(String bookId) async {
    await ref.read(deleteBookUseCaseProvider).call(bookId);
    ref.invalidate(booksForSubjectProvider(widget.subjectId));
  }

  /// ساختاربندی خودکار سمت سرور — مستقیماً از متن ذخیره‌شدهٔ کتاب (بدون نیاز
  /// به فایل PDF یا تشخیص کلاینت) فصل/درس می‌سازد. هم بلافاصله بعد از آپلود
  /// (وقتی تشخیص کلاینت ناکافی بود) و هم از دکمهٔ «بازسازی نصاب» روی
  /// کتاب‌های قبلاً آپلودشدهٔ بدون فصل صدا زده می‌شود؛ همیشه یک پیام واضح
  /// نتیجه (موفق یا ناموفق) نشان می‌دهد — هرگز بی‌صدا رها نمی‌شویم.
  Future<void> _autoStructureOnServer(String bookId, {bool isFallback = false}) async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .post('/admin/curriculum-library/books/$bookId/auto-structure');
      final map = Map<String, dynamic>.from(data as Map? ?? {});
      final chaptersCreated = (map['chaptersCreated'] as num?)?.toInt() ?? 0;
      final lessonsCreated = (map['lessonsCreated'] as num?)?.toInt() ?? 0;
      if (mounted) {
        setState(() => _chapterInfo = chaptersCreated > 0
            ? context.tr('curriculumBook.autoStructuredNotice', {'chapters': '$chaptersCreated', 'lessons': '$lessonsCreated'})
            : context.tr('curriculumBook.autoStructureEmpty'));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _chapterInfo = isFallback
            ? context.tr('curriculumBook.uploadOkStructureFailed')
            : context.tr('curriculumBook.rebuildFailedRetry'));
      }
    } finally {
      ref.invalidate(booksForSubjectProvider(widget.subjectId));
      _invalidateStudentCurriculumCaches(ref);
    }
  }

  /// دکمهٔ «بازسازی نصاب» روی کتاب‌های قبلاً آپلودشده که هنوز فصل‌بندی
  /// نشده‌اند (مثلاً همان «چند کتاب نمونه»ای که پیش از این رفع اشکال آپلود
  /// شده بودند) — بدون نیاز به آپلود دوبارهٔ فایل PDF.
  Future<void> _rebuildFromExisting(String bookId) async {
    if (!kUseLiveBackend) {
      setState(() => _chapterInfo = context.tr('curriculumBook.localModeRebuildNotice'));
      return;
    }
    setState(() {
      _rebuilding = true;
      _chapterInfo = null;
    });
    await _autoStructureOnServer(bookId, isFallback: false);
    if (mounted) setState(() => _rebuilding = false);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final book = widget.book;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: book != null ? scheme.primary.withValues(alpha: 0.14) : scheme.outlineVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text('${widget.grade}',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                        color: book != null ? scheme.primary : scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: book != null
                    ? Text(book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))
                    : Text(context.tr('curriculumBook.notUploadedYet'),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
              if (book != null) ...[
                _ChapterSyncChip(
                  book: book,
                  rebuilding: _rebuilding,
                  onRebuild: () => _rebuildFromExisting(book.id),
                ),
                const SizedBox(width: 6),
                Text(context.tr('curriculumBook.pageCountSuffix', {'count': '${book.pageCount}'}),
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.edit_note_rounded, color: scheme.secondary),
                  tooltip: context.tr('curriculumBook.editLessonsTooltip'),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => LessonEditorScreen(
                      subjectId: widget.subjectId,
                      grade: widget.grade,
                      subjectNameFa: widget.subjectNameFa,
                    ),
                  )),
                ),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  onPressed: () => _delete(book.id),
                  tooltip: context.tr('common.delete'),
                ),
              ] else
                TextButton.icon(
                  onPressed: _extracting ? null : _pickAndUpload,
                  icon: _extracting
                      ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(_extracting ? context.tr('curriculumBook.uploadingLabel') : context.tr('curriculumBook.uploadLabel'), style: const TextStyle(fontSize: 12.5)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
            ],
          ),

          // ── کارت پیشرفت آپلود — مدرن و پویا، با نمایش زندهٔ زمان سپری‌شده ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              axisAlignment: -1,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _extracting
                ? Container(
                    key: const ValueKey('uploading'),
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradientWarm,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      boxShadow: AppShadows.warm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            AnimatedBuilder(
                              animation: _pulseController,
                              builder: (context, child) => Transform.scale(
                                scale: 0.85 + (_pulseController.value * 0.3),
                                child: child,
                              ),
                              child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(context.tr('curriculumBook.uploadingProcessingNotice'),
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                _elapsedLabel,
                                key: ValueKey(_elapsedLabel),
                                style: const TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: LinearProgressIndicator(
                            minHeight: 5,
                            backgroundColor: Colors.white.withValues(alpha: 0.28),
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('idle')),
          ),

          if (_extractError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_extractError!, style: TextStyle(color: scheme.error, fontSize: 11.5)),
            ),

          // ── پیام موفقیت آپلود — بلافاصله بعد از اتمام آپلود نمایان می‌شود و
          // پس از چند ثانیه خودش محو می‌شود ──
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => SizeTransition(
              sizeFactor: anim,
              axisAlignment: -1,
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: _showSuccess
                ? Container(
                    key: const ValueKey('success'),
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: AppColors.successGradient,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                      boxShadow: AppShadows.green,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            context.tr('curriculumBook.uploadSuccessWithGradeAndDuration', {
                              'grade': '${widget.grade}',
                              'seconds': (_lastUploadDuration.inMilliseconds / 1000).toStringAsFixed(1),
                            }),
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('no-success')),
          ),

          if (_chapterInfo != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 13, color: scheme.primary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(_chapterInfo!,
                        style: TextStyle(fontSize: 11.5, color: scheme.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// نشانگر کوچک هماهنگی نصاب — دقیقاً نقطه‌ای که مدیر بدون آن نمی‌دانست چرا
/// نصاب شاگردان خالی مانده: کتاب می‌تواند «آپلود شده» باشد (در کتابخانهٔ
/// نصاب/مدیریت معلم هوشمند دیده شود) بدون آن‌که هنوز به فصل/درس واقعی روی
/// نصاب شاگرد تبدیل شده باشد. سبز = هماهنگ؛ نارنجی = هنوز فصل‌بندی نشده،
/// با دکمهٔ «بازسازی نصاب» برای رفع فوری بدون آپلود دوبارهٔ فایل.
class _ChapterSyncChip extends StatelessWidget {
  final CurriculumBook book;
  final bool rebuilding;
  final VoidCallback onRebuild;

  const _ChapterSyncChip({
    required this.book,
    required this.rebuilding,
    required this.onRebuild,
  });

  @override
  Widget build(BuildContext context) {
    final synced = !book.needsStructuring;
    final color = synced ? AppColors.green600 : AppColors.orange600;
    final bg = synced ? AppColors.green50 : AppColors.orange50;
    final label = synced
        ? context.tr('curriculumBook.chapterCountChip', {'count': '${book.chapterCount}'})
        : context.tr('curriculumBook.notStructuredChip');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(synced ? Icons.check_circle_rounded : Icons.warning_amber_rounded, size: 12, color: color),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
          if (!synced) ...[
            const SizedBox(width: 2),
            GestureDetector(
              onTap: rebuilding ? null : onRebuild,
              child: Padding(
                padding: const EdgeInsets.only(right: 2),
                child: rebuilding
                    ? SizedBox(
                        width: 11,
                        height: 11,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
                      )
                    : Icon(Icons.refresh_rounded, size: 13, color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
