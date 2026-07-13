import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../../shared_models/subject.dart';
import '../../data/services/bulk_book_importer.dart';
import '../../data/datasources/curriculum_library_local_datasource.dart'; // اضافه شد برای کست کردن تایپ
import '../providers/curriculum_library_providers.dart';

/// صفحهٔ «ورود دسته‌ای کتاب‌های نصاب» — همهٔ PDF های دانلودشده را یک‌جا
/// انتخاب کنید؛ مضمون و صنف هر فایل خودکار تشخیص و وارد کتابخانهٔ معلم
/// هوشمند می‌شود. موارد تشخیص‌نشده را می‌توان دستی اصلاح کرد.
class BulkImportScreen extends ConsumerStatefulWidget {
  const BulkImportScreen({super.key});

  @override
  ConsumerState<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends ConsumerState<BulkImportScreen> {
  final List<BulkImportItem> _items = [];
  bool _importing = false;
  int _doneCount = 0;

  Future<void> _pickFiles() async {
    FilePickerResult? result;
    try {
      // اصلاح شد: بازگشت به سینتکس اصلی و صحیح پکیج شما
      result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: true,
        withData: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('انتخاب فایل ناموفق بود: $e')));
      }
      return;
    }
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _items
        ..clear()
        ..addAll(result!.files.map(BulkImportItem.new));
      _doneCount = 0;
    });
  }

  Future<void> _startImport() async {
    if (_importing) return;
    setState(() => _importing = true);

    // اصلاح شد: استفاده از پرووایدر اصلی شما و کست کردن آن به تایپ مورد نیاز Importer
    final dataSource = ref.read(curriculumLibraryDataSourceProvider) as CurriculumLibraryLocalDataSource;
    final importer = BulkBookImporter(dataSource);

    for (final item in _items) {
      if (item.status == BulkItemStatus.done) continue;
      setState(() => item.status = BulkItemStatus.importing);
      await importer.importItem(item);
      setState(() {
        if (item.status == BulkItemStatus.done) _doneCount++;
      });
      // فرصت رندر بین فایل‌های سنگین
      await Future.delayed(const Duration(milliseconds: 30));
    }
    setState(() => _importing = false);
    ref.invalidate(booksForSubjectProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$_doneCount کتاب با موفقیت وارد کتابخانهٔ معلم هوشمند شد ✅'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final detected = _items
        .where((i) => i.subjectId != null && i.grade != null)
        .length;

    return AppScaffold(
      title: 'ورود دسته‌ای کتاب‌های نصاب',
      role: AppUserRole.superAdmin,
      body: Column(
        children: [
          // ── سربرگ راهنما ──
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppRadii.xl),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_stories_rounded,
                    color: Colors.white, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('کتاب‌های صنف ۷ الی ۱۲ را یک‌جا وارد کنید',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(
                        'مضمون و صنف از نام فایل (مثل Math_G7.pdf) خودکار تشخیص داده می‌شود.',
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: .9),
                            fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // ── دکمه‌ها ──
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: _importing ? null : _pickFiles,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: Text(_items.isEmpty
                        ? 'انتخاب فایل‌های PDF'
                        : '${_items.length} فایل انتخاب شد'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                    _items.isEmpty || _importing ? null : _startImport,
                    icon: _importing
                        ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_done_rounded),
                    label: Text(_importing
                        ? 'در حال ورود…'
                        : 'شروع ورود ($detected آماده)'),
                  ),
                ),
              ],
            ),
          ),
          if (_items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _items.isEmpty ? 0 : _doneCount / _items.length,
                  minHeight: 6,
                ),
              ),
            ),
          const SizedBox(height: 8),
          // ── لیست فایل‌ها ──
          Expanded(
            child: _items.isEmpty
                ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.picture_as_pdf_rounded,
                      size: 56, color: scheme.outlineVariant),
                  const SizedBox(height: 12),
                  Text('هنوز فایلی انتخاب نشده است',
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                ],
              ),
            )
                : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _ImportRow(
                item: _items[i],
                enabled: !_importing,
                onChanged: () => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportRow extends StatelessWidget {
  final BulkImportItem item;
  final bool enabled;
  final VoidCallback onChanged;
  const _ImportRow(
      {required this.item, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, color) = switch (item.status) {
      BulkItemStatus.done => (Icons.check_circle_rounded, Colors.green),
      BulkItemStatus.failed => (Icons.error_rounded, scheme.error),
      BulkItemStatus.skipped => (Icons.help_rounded, Colors.orange),
      BulkItemStatus.importing =>
      (Icons.hourglass_top_rounded, scheme.primary),
      BulkItemStatus.pending => (Icons.picture_as_pdf_rounded,
      item.subjectId != null && item.grade != null
          ? scheme.primary
          : Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // مضمون
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: item.subjectId,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'مضمون', border: OutlineInputBorder()),
                  items: mockSubjects
                      .map((s) => DropdownMenuItem(
                      value: s.id, child: Text(s.nameFa)))
                      .toList(),
                  onChanged: enabled && item.status != BulkItemStatus.done
                      ? (v) {
                    item.subjectId = v;
                    onChanged();
                  }
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              // صنف
              SizedBox(
                width: 110,
                child: DropdownButtonFormField<int>(
                  value: item.grade,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'صنف', border: OutlineInputBorder()),
                  items: [for (var g = 7; g <= 12; g++) g]
                      .map((g) =>
                      DropdownMenuItem(value: g, child: Text('صنف $g')))
                      .toList(),
                  onChanged: enabled && item.status != BulkItemStatus.done
                      ? (v) {
                    item.grade = v;
                    onChanged();
                  }
                      : null,
                ),
              ),
            ],
          ),
          if (item.message != null) ...[
            const SizedBox(height: 6),
            Text(item.message!,
                style: TextStyle(
                    fontSize: 11,
                    color: item.status == BulkItemStatus.done
                        ? Colors.green
                        : scheme.error)),
          ],
        ],
      ),
    );
  }
}
