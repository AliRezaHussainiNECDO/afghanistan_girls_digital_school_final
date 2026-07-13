import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../shared_models/app_notification.dart';
import '../../data/academy_store.dart';
import '../../data/pdf_picker/pdf_picker.dart';
import '../../data/pdf_picker/picked_pdf.dart';
import '../../domain/academy_entities.dart';
import '../academy_providers.dart';
import 'academy_shared.dart';

void _refresh(WidgetRef ref) {
  ref.invalidate(cmsBooksListProvider);
  ref.invalidate(publishedBooksProvider);
}

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
  );
}

// ═══════════════════════ BOOK FORM (upload/edit) ═══════════════════════
class BookFormSheet extends ConsumerStatefulWidget {
  final LibraryBook? existing;
  const BookFormSheet({super.key, this.existing});
  @override
  ConsumerState<BookFormSheet> createState() => _BookFormSheetState();
}

class _BookFormSheetState extends ConsumerState<BookFormSheet> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _author = TextEditingController(text: widget.existing?.author ?? '');
  late final _description = TextEditingController(text: widget.existing?.description ?? '');
  late final _pages = TextEditingController(text: (widget.existing?.pageCount ?? '').toString());
  late String _subject = widget.existing?.subject ?? kSubjects.first;
  late int _grade = widget.existing?.gradeId ?? 0;
  late String _category = widget.existing?.category ?? kCategories.first;
  late int _cover = widget.existing?.coverIndex ?? 0;
  late bool _publish = widget.existing?.status == PublishStatus.published;
  late bool _includeInRag = widget.existing?.includeInRag ?? false;

  String _pdfName = '';
  String _pdfPath = '';
  double _pdfSize = 0;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _pdfName = widget.existing?.pdfFileName ?? '';
    _pdfPath = widget.existing?.pdfPath ?? '';
    _pdfSize = widget.existing?.fileSizeMb ?? 0;
  }

  @override
  void dispose() {
    for (final c in [_title, _author, _description, _pages]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPdf() async {
    setState(() => _picking = true);
    try {
      final PickedPdf? picked = await pickPdfFile();
      if (picked != null) {
        setState(() {
          _pdfName = picked.name;
          _pdfPath = picked.path;
          _pdfSize = picked.sizeMb;
        });
      }
    } catch (e) {
      if (mounted) _toast(context, 'انتخاب فایل ناموفق بود');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _toast(context, 'عنوان کتاب اجباری است');
      return;
    }
    final book = LibraryBook(
      id: widget.existing?.id ?? 'new',
      title: _title.text.trim(),
      subject: _subject,
      gradeId: _grade,
      category: _category,
      author: _author.text.trim(),
      description: _description.text.trim(),
      pdfFileName: _pdfName,
      pdfPath: _pdfPath,
      fileSizeMb: double.parse(_pdfSize.toStringAsFixed(1)),
      pageCount: int.tryParse(_pages.text.trim()) ?? 0,
      coverIndex: _cover,
      includeInRag: _includeInRag,
      status: _publish ? PublishStatus.published : PublishStatus.draft,
      uploadedAt: widget.existing?.uploadedAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final saved = AcademyStore().saveBook(book);
    _refresh(ref);
    if (saved.status == PublishStatus.published) {
      NotificationCenter.instance.push(
        title: 'کتاب جدید در کتابخانه 📚',
        body: '«${saved.title}» (${saved.subject} · ${saved.gradeLabel}) اکنون در دسترس است.',
        kind: NotificationKind.book,
      );
    }
    if (mounted) {
      Navigator.pop(context);
      _toast(context, 'کتاب ذخیره شد');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.existing == null ? 'کتاب جدید' : 'ویرایش کتاب',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const SizedBox(height: 16),
              // ── آپلود پی‌دی‌اف ──
              InkWell(
                onTap: _picking ? null : _pickPdf,
                borderRadius: BorderRadius.circular(AppRadii.md),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: _pdfName.isEmpty ? scheme.outlineVariant : AppColors.green600.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(_pdfName.isEmpty ? Icons.upload_file_rounded : Icons.picture_as_pdf_rounded,
                          color: _pdfName.isEmpty ? scheme.onSurfaceVariant : AppColors.danger),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_pdfName.isEmpty ? 'انتخاب فایل پی‌دی‌اف کتاب' : _pdfName,
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700)),
                            if (_pdfSize > 0)
                              Text('${_pdfSize.toStringAsFixed(1)} MB',
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      if (_picking)
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Icon(Icons.attach_file_rounded, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              academyField(_title, 'عنوان کتاب'),
              _dropdown<String>('مضمون', _subject, kSubjects.map((s) => (s, s)).toList(),
                  (v) => setState(() => _subject = v)),
              _dropdown<int>('صنف', _grade, kGrades.map((g) => (g, gradeLabel(g))).toList(),
                  (v) => setState(() => _grade = v)),
              _dropdown<String>('دسته‌بندی', _category, kCategories.map((c) => (c, c)).toList(),
                  (v) => setState(() => _category = v)),
              academyField(_author, 'نویسنده / ناشر'),
              academyField(_pages, 'تعداد صفحات', keyboard: TextInputType.number),
              academyField(_description, 'توضیحات', maxLines: 3),
              // ── انتخاب رنگ جلد ──
              Align(
                alignment: Alignment.centerRight,
                child: Text('رنگ جلد', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: List.generate(kCoverGradients.length, (i) {
                  final selected = i == _cover;
                  return GestureDetector(
                    onTap: () => setState(() => _cover = i),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: coverFor(i)),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: selected ? scheme.onSurface : Colors.transparent, width: 2.5),
                      ),
                      child: selected ? const Icon(Icons.check_rounded, color: Colors.white, size: 18) : null,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _includeInRag,
                onChanged: (v) => setState(() => _includeInRag = v),
                title: const Text('استفاده در معلم هوشمند (RAG)', style: TextStyle(fontSize: 14)),
                subtitle: const Text('متن این کتاب به هوش مصنوعی داده شود', style: TextStyle(fontSize: 11)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _publish,
                onChanged: (v) => setState(() => _publish = v),
                title: const Text('انتشار برای شاگردان', style: TextStyle(fontSize: 14)),
                subtitle: const Text('در کتابخانهٔ شاگردان قابل دیدن/دانلود شود', style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context), child: const Text('انصراف')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('ذخیره'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dropdown<T>(String label, T value, List<(T, String)> items, ValueChanged<T> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
        items: items.map((e) => DropdownMenuItem<T>(value: e.$1, child: Text(e.$2))).toList(),
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

// ═══════════════════════ BOOK DETAIL (admin) ═══════════════════════
class BookDetailSheet extends ConsumerWidget {
  final LibraryBook book;
  const BookDetailSheet({super.key, required this.book});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final published = book.status == PublishStatus.published;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 68,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: coverFor(book.coverIndex),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(book.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          _tag('${book.subject} · ${book.gradeLabel}'),
                          PublishChip(status: book.status),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InfoRow('دسته‌بندی', book.category),
              InfoRow('نویسنده / ناشر', book.author),
              InfoRow('توضیحات', book.description),
              if (book.hasPdf || book.pdfFileName.isNotEmpty)
                InfoRow('فایل پی‌دی‌اف', '${book.pdfFileName}${book.fileSizeMb > 0 ? ' · ${book.fileSizeMb} MB' : ''}'),
              InfoRow('تعداد صفحات', book.pageCount > 0 ? '${book.pageCount}' : ''),
              InfoRow('معلم هوشمند', book.includeInRag ? 'فعال' : 'غیرفعال'),
              InfoRow('آخرین به‌روزرسانی', formatDate(book.updatedAt)),
              const Divider(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: (published ? AppColors.ink500 : AppColors.green600).withValues(alpha: 0.14),
                      foregroundColor: published ? AppColors.ink500 : AppColors.green600,
                    ),
                    onPressed: () async {
                      AcademyStore().setBookStatus(
                          book.id, published ? PublishStatus.draft : PublishStatus.published);
                      _refresh(ref);
                      if (!published) {
                        NotificationCenter.instance.push(
                          title: 'کتاب جدید در کتابخانه 📚',
                          body: '«${book.title}» (${book.subject} · ${book.gradeLabel}) اکنون در دسترس است.',
                          kind: NotificationKind.book,
                        );
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        _toast(context, published ? 'از انتشار خارج شد' : 'منتشر شد');
                      }
                    },
                    icon: Icon(published ? Icons.unpublished_rounded : Icons.publish_rounded, size: 18),
                    label: Text(published ? 'خارج‌کردن از انتشار' : 'انتشار'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showAcademySheet(context, BookFormSheet(existing: book));
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('ویرایش'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                    ),
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('حذف'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String text) => Builder(builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Text(text, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
        );
      });

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف این کتاب؟'),
        content: const Text('این عمل قابل بازگشت نیست.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (ok == true) {
      AcademyStore().deleteBook(book.id);
      _refresh(ref);
      if (context.mounted) {
        Navigator.pop(context);
        _toast(context, 'حذف شد');
      }
    }
  }
}

// ═══════════════════════ STUDENT BOOK VIEW (library) ═══════════════════════
class StudentBookSheet extends StatefulWidget {
  final LibraryBook book;
  const StudentBookSheet({super.key, required this.book});
  @override
  State<StudentBookSheet> createState() => _StudentBookSheetState();
}

class _StudentBookSheetState extends State<StudentBookSheet> {
  bool _downloading = false;

  Future<void> _download() async {
    final book = widget.book;
    setState(() => _downloading = true);
    try {
      // شبیه‌سازی دانلود (سازگار با وب و موبایل). در فاز اتصال به Backend،
      // اینجا فایل واقعی از سرور دریافت/ذخیره می‌شود.
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (book.pdfFileName.isEmpty && !book.hasPdf) {
        _toast(context, 'برای این کتاب فعلاً فایلی موجود نیست');
      } else {
        _toast(context, 'کتاب «${book.title}» دانلود شد ✓');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final book = widget.book;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 92,
                  height: 118,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: coverFor(book.coverIndex),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    boxShadow: AppShadows.soft,
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 40),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(book.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              ),
              const SizedBox(height: 6),
              Center(
                child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  _pill(context, '${book.subject} · ${book.gradeLabel}'),
                  _pill(context, book.category),
                  if (book.fileSizeMb > 0) _pill(context, '${book.fileSizeMb} MB'),
                  if (book.pageCount > 0) _pill(context, '${book.pageCount} صفحه'),
                ]),
              ),
              const SizedBox(height: 16),
              if (book.author.isNotEmpty) InfoRow('نویسنده / ناشر', book.author),
              if (book.description.isNotEmpty) InfoRow('دربارهٔ کتاب', book.description),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _downloading ? null : _download,
                  icon: _downloading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded),
                  label: Text(_downloading ? 'در حال دانلود…' : 'دانلود کتاب'),
                ),
              ),
              const SizedBox(height: 8),
              Text('برای آموزش این کتاب می‌توانی از «معلم هوشمند» هم کمک بگیری.',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(BuildContext context, String text) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
    );
  }
}
