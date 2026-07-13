import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/curriculum_book.dart';
import '../../domain/usecases/curriculum_library_usecases.dart';
import '../providers/curriculum_library_providers.dart';

/// بخش «کتاب‌های نصاب تعلیمی» برای هر مضمون — مدیر از این‌جا کتاب پی‌دی‌اف
/// رسمی وزارت معارف را برای هر صنف (۷ الی ۱۲) به‌طور جداگانه آپلود می‌کند؛
/// طبق نصاب رسمی هر صنف کتاب مستقل خودش را دارد، پس معلم هوشمند باید بتواند
/// دقیقاً از روی کتاب همان صنف شاگرد تدریس کند (طبق درخواست صریح کاربر).
/// متن هر کتاب به‌صورت محلی استخراج می‌شود و پایهٔ تدریس واقعی می‌گردد.
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

class _GradeBookRowState extends ConsumerState<_GradeBookRow> {
  bool _extracting = false;
  String? _extractError;
  Future<void> _pickAndUpload() async {
    setState(() => _extractError = null);
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
    try {
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      final pageCount = document.pages.count;
      document.dispose();

      if (text.trim().isEmpty) {
        setState(() {
          _extracting = false;
          _extractError = 'متنی از این پی‌دی‌اف استخراج نشد (شاید اسکن‌شده/تصویری باشد).';
        });
        return;
      }

      final title = file.name.replaceAll('.pdf', '');
      await ref.read(addBookUseCaseProvider).call(AddBookParams(
            subjectId: widget.subjectId,
            title: title,
            pageCount: pageCount,
            gradeId: widget.grade,
            extractedText: text,
          ));
      ref.invalidate(booksForSubjectProvider(widget.subjectId));
      if (mounted) setState(() => _extracting = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _extracting = false;
        _extractError = 'خطا در پردازش پی‌دی‌اف: $e';
      });
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
                  label: Text(_extracting ? 'در حال پردازش...' : 'آپلود', style: const TextStyle(fontSize: 12.5)),
                  style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                ),
            ],
          ),
          if (_extractError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(_extractError!, style: TextStyle(color: scheme.error, fontSize: 11.5)),
            ),
        ],
      ),
    );
  }
}
