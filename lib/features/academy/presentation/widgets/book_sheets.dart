import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/notifications/notification_center.dart';
import '../../../../shared_models/app_notification.dart';
import '../../data/pdf_picker/pdf_picker.dart';
import '../../data/pdf_picker/picked_pdf.dart';
import '../../data/pdf_saver/pdf_saver.dart';
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
  String _pdfKey = '';
  double _pdfSize = 0;
  PickedPdf? _pickedPdf; // فایل تازه‌انتخاب‌شده که هنوز آپلود نشده
  bool _picking = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pdfName = widget.existing?.pdfFileName ?? '';
    _pdfPath = widget.existing?.pdfPath ?? '';
    _pdfKey = widget.existing?.pdfKey ?? '';
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
          _pickedPdf = picked;
          _pdfName = picked.name;
          _pdfPath = picked.path;
          _pdfSize = picked.sizeMb;
        });
      }
    } catch (e) {
      if (mounted) _toast(context, context.tr('academy.pdfPickFailed'));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      _toast(context, context.tr('academy.bookTitleRequired'));
      return;
    }
    setState(() => _saving = true);
    try {
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
        pdfKey: _pdfKey,
        fileSizeMb: double.parse(_pdfSize.toStringAsFixed(1)),
        pageCount: int.tryParse(_pages.text.trim()) ?? 0,
        coverIndex: _cover,
        includeInRag: _includeInRag,
        status: _publish ? PublishStatus.published : PublishStatus.draft,
        uploadedAt: widget.existing?.uploadedAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final store = ref.read(academyStoreProvider);
      // منتظر می‌مانیم تا ردیف کتاب واقعاً روی سرور ساخته/به‌روز شود — وگرنه
      // (چون نوشتن معمولیِ AcademyStore «آتش‌وفراموش» است) آپلود فایل ممکن
      // است زودتر از آماده‌شدن ردیف برسد و با خطای «کتاب یافت نشد» مواجه شود.
      var saved = await store.saveBookAwaitingServer(book);

      // اگر فایل تازه‌ای انتخاب شده، اکنون واقعاً روی سرور آپلود می‌شود
      // (قبلاً این مرحله کاملاً شبیه‌سازی بود و هیچ فایلی ذخیره نمی‌شد).
      if (_pickedPdf != null) {
        final bytes = await readPickedPdfBytes(_pickedPdf!);
        if (bytes != null && bytes.isNotEmpty) {
          final uploaded = await store.uploadBookPdf(saved.id, bytes, _pdfName);
          if (uploaded != null) saved = uploaded;
        } else if (mounted) {
          _toast(context, context.tr('academy.bookSavedPdfUploadFailed'));
        }
      }

      _refresh(ref);
      // بعد از await های بالا (ذخیره/آپلود روی سرور) — قبل از استفادهٔ بعدی
      // از context باید مطمئن شویم ویجت هنوز در درخت است.
      if (!mounted) return;
      if (saved.status == PublishStatus.published) {
        NotificationCenter.instance.push(
          title: context.tr('academy.newBookNotifTitle'),
          body: context.tr('academy.newBookNotifBody', {
            'title': saved.title,
            'subject': saved.subject,
            'grade': gradeLabel(context, saved.gradeId),
          }),
          kind: NotificationKind.book,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        _toast(context, context.tr('academy.bookSaved'));
      }
    } catch (e) {
      if (mounted) _toast(context, context.tr('academy.saveFailedWithError', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _saving = false);
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
              Text(widget.existing == null ? context.tr('academy.newBookTitle') : context.tr('academy.editBookTitle'),
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
                            Text(_pdfName.isEmpty ? context.tr('academy.selectPdfFile') : _pdfName,
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
              academyField(_title, context.tr('academy.bookTitleLabel')),
              _dropdown<String>(context.tr('academy.subjectLabel'), _subject, kSubjects.map((s) => (s, s)).toList(),
                  (v) => setState(() => _subject = v)),
              _dropdown<int>(context.tr('common.grade'), _grade,
                  kGrades.map((g) => (g, gradeLabel(context, g))).toList(),
                  (v) => setState(() => _grade = v)),
              _dropdown<String>(context.tr('academy.categoryLabel'), _category, kCategories.map((c) => (c, c)).toList(),
                  (v) => setState(() => _category = v)),
              academyField(_author, context.tr('academy.authorPublisherLabel')),
              academyField(_pages, context.tr('academy.pageCountLabel'), keyboard: TextInputType.number),
              academyField(_description, context.tr('academy.descriptionLabel'), maxLines: 3),
              // ── انتخاب رنگ جلد ──
              Align(
                alignment: Alignment.centerRight,
                child: Text(context.tr('academy.coverColorLabel'), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
                title: Text(context.tr('academy.useInAiTeacherTitle'), style: const TextStyle(fontSize: 14)),
                subtitle: Text(context.tr('academy.useInAiTeacherSubtitle'), style: const TextStyle(fontSize: 11)),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _publish,
                onChanged: (v) => setState(() => _publish = v),
                title: Text(context.tr('academy.publishForStudentsTitle'), style: const TextStyle(fontSize: 14)),
                subtitle: Text(context.tr('academy.publishForStudentsSubtitle'), style: const TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed: _saving ? null : () => Navigator.pop(context), child: Text(context.tr('common.cancel'))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: Text(_saving ? context.tr('academy.savingInProgress') : context.tr('common.save')),
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
                          _tag('${book.subject} · ${gradeLabel(context, book.gradeId)}'),
                          PublishChip(status: book.status),
                        ]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              InfoRow(context.tr('academy.categoryLabel'), book.category),
              InfoRow(context.tr('academy.authorPublisherLabel'), book.author),
              InfoRow(context.tr('academy.descriptionLabel'), book.description),
              if (book.hasPdf || book.pdfFileName.isNotEmpty)
                InfoRow(context.tr('academy.pdfFileLabel'),
                    '${book.pdfFileName}${book.fileSizeMb > 0 ? ' · ${book.fileSizeMb} MB' : ''}'),
              InfoRow(context.tr('academy.pageCountLabel'), book.pageCount > 0 ? '${book.pageCount}' : ''),
              InfoRow(context.tr('academy.aiTeacherLabel'),
                  book.includeInRag ? context.tr('academy.activeLabel') : context.tr('academy.inactiveLabel')),
              InfoRow(context.tr('academy.lastUpdatedLabel'), formatDate(book.updatedAt)),
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
                      ref.read(academyStoreProvider).setBookStatus(
                          book.id, published ? PublishStatus.draft : PublishStatus.published);
                      _refresh(ref);
                      if (!published) {
                        NotificationCenter.instance.push(
                          title: context.tr('academy.newBookNotifTitle'),
                          body: context.tr('academy.newBookNotifBody', {
                            'title': book.title,
                            'subject': book.subject,
                            'grade': gradeLabel(context, book.gradeId),
                          }),
                          kind: NotificationKind.book,
                        );
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        _toast(context, published
                            ? context.tr('academy.unpublishedNotice')
                            : context.tr('academy.publishedNotice'));
                      }
                    },
                    icon: Icon(published ? Icons.unpublished_rounded : Icons.publish_rounded, size: 18),
                    label: Text(published ? context.tr('academy.unpublishButton') : context.tr('academy.publishButton')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      showAcademySheet(context, BookFormSheet(existing: book));
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: Text(context.tr('academy.editButton')),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error.withValues(alpha: 0.5)),
                    ),
                    onPressed: () => _confirmDelete(context, ref),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: Text(context.tr('academy.deleteButton')),
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
        title: Text(context.tr('academy.deleteBookConfirmTitle')),
        content: Text(context.tr('academy.actionIrreversible')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.tr('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('academy.deleteButton')),
          ),
        ],
      ),
    );
    if (ok == true) {
      ref.read(academyStoreProvider).deleteBook(book.id);
      _refresh(ref);
      if (context.mounted) {
        Navigator.pop(context);
        _toast(context, context.tr('academy.deletedNotice'));
      }
    }
  }
}

// ═══════════════════════ STUDENT BOOK VIEW (library) ═══════════════════════
class StudentBookSheet extends ConsumerStatefulWidget {
  final LibraryBook book;
  const StudentBookSheet({super.key, required this.book});
  @override
  ConsumerState<StudentBookSheet> createState() => _StudentBookSheetState();
}

class _StudentBookSheetState extends ConsumerState<StudentBookSheet> {
  bool _downloading = false;

  /// دانلود واقعی — رفع اشکال: قبلاً این فقط یک تأخیر ۵۰۰ میلی‌ثانیه‌ای +
  /// پیام موفقیت جعلی بود؛ هیچ فایلی واقعاً دریافت/ذخیره نمی‌شد. اکنون
  /// بایت‌های واقعی از سرور گرفته و روی دستگاه ذخیره می‌شود (یا در وب،
  /// دانلود مرورگر آغاز می‌شود).
  Future<void> _download() async {
    final book = widget.book;
    if (!book.hasPdf) {
      _toast(context, context.tr('academy.noPdfAvailable'));
      return;
    }
    setState(() => _downloading = true);
    try {
      final bytes = await ref.read(academyStoreProvider).downloadBookPdf(book.pdfKey);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) _toast(context, context.tr('academy.downloadFailedRetry'));
        return;
      }
      final fileName = book.pdfFileName.isNotEmpty ? book.pdfFileName : '${book.title}.pdf';
      await savePdfBytes(fileName, bytes);
      if (!mounted) return;
      _toast(context, context.tr('academy.bookDownloadedNotice', {'title': book.title}));
    } catch (e) {
      if (mounted) _toast(context, context.tr('academy.downloadError', {'error': '$e'}));
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
                  _pill(context, '${book.subject} · ${gradeLabel(context, book.gradeId)}'),
                  _pill(context, book.category),
                  if (book.fileSizeMb > 0) _pill(context, '${book.fileSizeMb} MB'),
                  if (book.pageCount > 0)
                    _pill(context, context.tr('academy.pagesCountSuffix', {'count': '${book.pageCount}'})),
                ]),
              ),
              const SizedBox(height: 16),
              if (book.author.isNotEmpty) InfoRow(context.tr('academy.authorPublisherLabel'), book.author),
              if (book.description.isNotEmpty) InfoRow(context.tr('academy.aboutBookLabel'), book.description),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _downloading ? null : _download,
                  icon: _downloading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.download_rounded),
                  label: Text(_downloading ? context.tr('academy.downloadingInProgress') : context.tr('academy.downloadBookButton')),
                ),
              ),
              const SizedBox(height: 8),
              Text(context.tr('academy.aiTeacherHelpHint'),
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
