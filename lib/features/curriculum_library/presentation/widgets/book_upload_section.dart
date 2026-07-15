import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../domain/entities/curriculum_book.dart';
import '../../domain/services/chapter_detector.dart';
import '../../domain/usecases/curriculum_library_usecases.dart';
import '../providers/curriculum_library_providers.dart';

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
                child: Text('کتاب‌های نصاب — $subjectNameFa (صنف ۷ الی ۱۲)',
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
            error: (e, st) => Text('خطا: $e', style: TextStyle(color: scheme.error, fontSize: 12)),
            data: (books) {
              final byGrade = <int, CurriculumBook>{
                for (final b in books.where((b) => AppConstants.grades.contains(b.gradeId))) b.gradeId: b,
              };
              return Column(
                children: AppConstants.grades
                    .map((grade) => _GradeBookRow(
                          subjectId: subjectId,
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
  final int grade;
  final CurriculumBook? book;

  const _GradeBookRow({required this.subjectId, required this.grade, required this.book});

  @override
  ConsumerState<_GradeBookRow> createState() => _GradeBookRowState();
}

class _GradeBookRowState extends ConsumerState<_GradeBookRow>
    with SingleTickerProviderStateMixin {
  bool _extracting = false;
  String? _extractError;

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
  late final AnimationController _pulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

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

  String get _elapsedLabel =>
      '${(_stopwatch.elapsedMilliseconds / 1000).toStringAsFixed(1)} ثانیه';

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
      if (mounted) setState(() => _extractError = 'انتخاب فایل ناموفق بود: $e');
      return;
    }
    if (!mounted || result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() => _extractError = 'خواندن فایل ناموفق بود.');
      return;
    }

    setState(() => _extracting = true);
    _startProgressClock();
    try {
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      final pageCount = document.pages.count;

      // ── شناسایی هوشمند عناوین فصل — پیش از dispose سند (به خطوط/فونت نیاز دارد) ──
      List<DetectedChapter> detectedChapters = const [];
      try {
        detectedChapters = ChapterDetector.detect(document);
      } catch (_) {
        detectedChapters = const []; // Fail-safe: شکست تشخیص فصل نباید آپلود را متوقف کند
      }
      document.dispose();

      if (text.trim().isEmpty) {
        setState(() {
          _extracting = false;
          _extractError = 'متنی از این پی‌دی‌اف استخراج نشد (شاید اسکن‌شده/تصویری باشد).';
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

      // ── انتشار فصل‌های شناسایی‌شده (فقط روی Backend واقعی و با اطمینان کافی) ──
      await addResult.fold((_) async {}, (book) async {
        if (!kUseLiveBackend || detectedChapters.length < 2) return;
        try {
          await ref.read(apiClientProvider).post(
            '/admin/curriculum/subjects/${widget.subjectId}/publish-chapters',
            data: {
              'bookId': book.id,
              'gradeId': widget.grade,
              'chapters': detectedChapters
                  .map((c) => {'title': c.title, 'content': c.content})
                  .toList(),
            },
          );
          if (mounted) {
            setState(() => _chapterInfo = '${detectedChapters.length} فصل شناسایی و منتشر شد ✓');
          }
        } catch (e) {
          if (mounted) {
            setState(() => _chapterInfo = 'آپلود موفق بود؛ فصل‌بندی خودکار ناموفق شد.');
          }
        }
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
        _extractError = 'خطا در پردازش پی‌دی‌اف: $e';
      });
    } finally {
      _stopProgressClock();
    }
  }

  Future<void> _delete(String bookId) async {
    await ref.read(deleteBookUseCaseProvider).call(bookId);
    ref.invalidate(booksForSubjectProvider(widget.subjectId));
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
                    : Text('هنوز آپلود نشده',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
              if (book != null) ...[
                Text('${book.pageCount} صفحه',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                IconButton(
                  iconSize: 18,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                  onPressed: () => _delete(book.id),
                  tooltip: 'حذف',
                ),
              ] else
                TextButton.icon(
                  onPressed: _extracting ? null : _pickAndUpload,
                  icon: _extracting
                      ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(_extracting ? 'در حال آپلود...' : 'آپلود', style: const TextStyle(fontSize: 12.5)),
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
                            const Expanded(
                              child: Text('در حال آپلود و پردازش کتاب...',
                                  style: TextStyle(
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
                            'کتاب صنف ${widget.grade} با موفقیت آپلود شد ✓  '
                            '(${(_lastUploadDuration.inMilliseconds / 1000).toStringAsFixed(1)} ثانیه)',
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
