import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/network_providers.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';

/// یک درس در نمای ویرایشگر — نسخهٔ سبک، فقط فیلدهای لازم برای این صفحه.
class _EditableLesson {
  final String id;
  final String chapterId;
  String titleFa;
  String contentBody;
  final int orderIndex;
  _EditableLesson({
    required this.id,
    required this.chapterId,
    required this.titleFa,
    required this.contentBody,
    required this.orderIndex,
  });
  factory _EditableLesson.fromJson(Map<String, dynamic> j) => _EditableLesson(
        id: j['id'] as String,
        chapterId: j['chapter_id'] as String,
        titleFa: j['title_fa'] as String? ?? '',
        contentBody: j['content_body'] as String? ?? '',
        orderIndex: (j['order_index'] as num?)?.toInt() ?? 0,
      );
}

class _EditableChapter {
  final String id;
  String titleFa;
  final int orderIndex;
  List<_EditableLesson> lessons;
  _EditableChapter({required this.id, required this.titleFa, required this.orderIndex, required this.lessons});
}

/// ویرایشگر کامل نصاب یک کتاب (فصل‌ها/درس‌ها) برای مدیر — طبق درخواست صریح
/// کاربر: «مدیریت معلم هوشمند» باید بتواند خودِ درس را ادیت کند، مشکلات کوچک
/// (متن نامنظم یک درس، ترتیب/فصل نادرست) را بدون آپلود دوبارهٔ کل کتاب رفع
/// کند، و بتواند درس‌ها را بین فصل‌ها جابجا/ادغام/تقسیم کند. تغییری که اینجا
/// ذخیره می‌شود مستقیماً روی همان جدول‌های سرور اعمال می‌شود که نصاب شاگردان
/// و آمار والدین از آن‌ها می‌خوانند — پس بلافاصله در همه‌جا منعکس می‌شود.
class LessonEditorScreen extends ConsumerStatefulWidget {
  final String subjectId;
  final int grade;
  final String subjectNameFa;
  const LessonEditorScreen({
    super.key,
    required this.subjectId,
    required this.grade,
    required this.subjectNameFa,
  });

  @override
  ConsumerState<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends ConsumerState<LessonEditorScreen> {
  bool _loading = true;
  String? _error;
  List<_EditableChapter> _chapters = [];
  final Set<String> _busyLessonIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final chData = await api.get('/subjects/${widget.subjectId}/chapters', queryParameters: {'grade': widget.grade});
      final chList = List<Map<String, dynamic>>.from((chData as Map)['chapters'] as List);
      final chapters = <_EditableChapter>[];
      for (final ch in chList) {
        final lsData = await api.get('/chapters/${ch['id']}/lessons');
        final lsList = List<Map<String, dynamic>>.from((lsData as Map)['lessons'] as List);
        chapters.add(_EditableChapter(
          id: ch['id'] as String,
          titleFa: ch['title_fa'] as String? ?? '',
          orderIndex: (ch['order_index'] as num?)?.toInt() ?? 0,
          lessons: lsList.map(_EditableLesson.fromJson).toList()..sort((a, b) => a.orderIndex.compareTo(b.orderIndex)),
        ));
      }
      chapters.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _editLesson(_EditableLesson lesson) async {
    final titleController = TextEditingController(text: lesson.titleFa);
    final contentController = TextEditingController(text: lesson.contentBody);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ویرایش درس'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'عنوان درس', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                maxLines: 12,
                minLines: 6,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'محتوای درس', border: OutlineInputBorder(), alignLabelWithHint: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ذخیره')),
        ],
      ),
    );
    if (saved != true) return;
    setState(() => _busyLessonIds.add(lesson.id));
    try {
      await ref.read(apiClientProvider).patch('/admin/curriculum-library/lessons/${lesson.id}', data: {
        'titleFa': titleController.text.trim(),
        'contentBody': contentController.text,
      });
      lesson.titleFa = titleController.text.trim();
      lesson.contentBody = contentController.text;
      _snack('درس ذخیره شد ✓');
      if (mounted) setState(() {});
    } catch (e) {
      _snack('خطا در ذخیره: $e');
    } finally {
      if (mounted) setState(() => _busyLessonIds.remove(lesson.id));
    }
  }

  Future<void> _rebuildLesson(_EditableLesson lesson) async {
    setState(() => _busyLessonIds.add(lesson.id));
    try {
      final data = await ref.read(apiClientProvider).post('/admin/curriculum-library/lessons/${lesson.id}/rebuild');
      final map = Map<String, dynamic>.from(data as Map? ?? {});
      final changed = map['changed'] == true;
      if (changed) {
        lesson.titleFa = map['titleFa'] as String? ?? lesson.titleFa;
        lesson.contentBody = map['contentBody'] as String? ?? lesson.contentBody;
      }
      _snack(changed ? 'متن این درس اصلاح شد ✓' : 'این درس مشکل متنی نداشت.');
      if (mounted) setState(() {});
    } catch (e) {
      _snack('خطا در بازسازی: $e');
    } finally {
      if (mounted) setState(() => _busyLessonIds.remove(lesson.id));
    }
  }

  Future<void> _deleteLesson(_EditableChapter chapter, _EditableLesson lesson) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف درس'),
        content: Text('«${lesson.titleFa}» برای همیشه حذف شود؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyLessonIds.add(lesson.id));
    try {
      await ref.read(apiClientProvider).delete('/admin/curriculum-library/lessons/${lesson.id}');
      chapter.lessons.removeWhere((l) => l.id == lesson.id);
      _snack('درس حذف شد.');
      if (mounted) setState(() {});
    } catch (e) {
      _snack('خطا در حذف: $e');
    } finally {
      if (mounted) setState(() => _busyLessonIds.remove(lesson.id));
    }
  }

  Future<void> _moveLesson(_EditableChapter fromChapter, _EditableLesson lesson) async {
    final target = await showDialog<_EditableChapter>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('جابجایی درس به فصل...'),
        children: _chapters
            .where((c) => c.id != fromChapter.id)
            .map((c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, c),
                  child: Text(c.titleFa),
                ))
            .toList(),
      ),
    );
    if (target == null) return;
    setState(() => _busyLessonIds.add(lesson.id));
    try {
      await ref.read(apiClientProvider).post('/admin/curriculum-library/lessons/${lesson.id}/move', data: {
        'targetChapterId': target.id,
      });
      fromChapter.lessons.removeWhere((l) => l.id == lesson.id);
      target.lessons.add(lesson);
      _snack('درس به «${target.titleFa}» منتقل شد.');
      if (mounted) setState(() {});
    } catch (e) {
      _snack('خطا در جابجایی: $e');
    } finally {
      if (mounted) setState(() => _busyLessonIds.remove(lesson.id));
    }
  }

  Future<void> _splitLesson(_EditableChapter chapter, _EditableLesson lesson) async {
    final mid = (lesson.contentBody.length / 2).round();
    final firstController = TextEditingController(text: lesson.contentBody.substring(0, mid));
    final secondController = TextEditingController(text: lesson.contentBody.substring(mid));
    final secondTitleController = TextEditingController(text: '${lesson.titleFa} (۲)');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقسیم درس به دو درس'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Align(
                alignment: Alignment.centerRight,
                child: Text('بخش‌بندی اولیه خودکار است — می‌توانید متن هر بخش را ویرایش کنید.',
                    style: TextStyle(fontSize: 11)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: firstController,
                maxLines: 6,
                minLines: 4,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'بخش اول (همین درس)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: secondTitleController,
                decoration: const InputDecoration(labelText: 'عنوان درس دوم', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: secondController,
                maxLines: 6,
                minLines: 4,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(labelText: 'بخش دوم (درس تازه)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('تقسیم کن')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyLessonIds.add(lesson.id));
    try {
      await ref.read(apiClientProvider).post('/admin/curriculum-library/lessons/${lesson.id}/split', data: {
        'firstContent': firstController.text,
        'secondContent': secondController.text,
        'secondTitleFa': secondTitleController.text.trim(),
      });
      _snack('درس تقسیم شد ✓');
      _busyLessonIds.remove(lesson.id);
      await _load();
    } catch (e) {
      _snack('خطا در تقسیم: $e');
      if (mounted) setState(() => _busyLessonIds.remove(lesson.id));
    }
  }

  Future<void> _mergeChapter(_EditableChapter source) async {
    final target = await showDialog<_EditableChapter>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('ادغام «${source.titleFa}» در...'),
        children: _chapters
            .where((c) => c.id != source.id)
            .map((c) => SimpleDialogOption(onPressed: () => Navigator.pop(ctx, c), child: Text(c.titleFa)))
            .toList(),
      ),
    );
    if (target == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأیید ادغام'),
        content: Text('همهٔ درس‌های «${source.titleFa}» به «${target.titleFa}» منتقل و فصل «${source.titleFa}» حذف می‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ادغام کن')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(apiClientProvider).post('/admin/curriculum-library/chapters/${source.id}/merge-into/${target.id}');
      _snack('فصل «${source.titleFa}» در «${target.titleFa}» ادغام شد.');
      await _load();
    } catch (e) {
      _snack('خطا در ادغام: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: 'ویرایش دروس — ${widget.subjectNameFa} (صنف ${widget.grade})',
      role: AppUserRole.superAdmin,
      body: _loading
          ? const LoadingView()
          : _error != null
              ? ErrorView(message: _error!)
              : _chapters.isEmpty
                  ? const Center(child: Text('هنوز فصل/درسی برای این کتاب ساخته نشده.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _chapters.length,
                      itemBuilder: (context, i) {
                        final chapter = _chapters[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ExpansionTile(
                            title: Text(chapter.titleFa, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${chapter.lessons.length} درس'),
                            trailing: IconButton(
                              icon: Icon(Icons.merge_type_rounded, color: scheme.secondary),
                              tooltip: 'ادغام این فصل در فصل دیگر',
                              onPressed: _chapters.length < 2 ? null : () => _mergeChapter(chapter),
                            ),
                            children: chapter.lessons.map((lesson) {
                              final busy = _busyLessonIds.contains(lesson.id);
                              return ListTile(
                                dense: true,
                                title: Text(lesson.titleFa),
                                subtitle: Text(
                                  lesson.contentBody.length > 80 ? '${lesson.contentBody.substring(0, 80)}…' : lesson.contentBody,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: busy
                                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            iconSize: 18,
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.edit_rounded),
                                            tooltip: 'ویرایش',
                                            onPressed: () => _editLesson(lesson),
                                          ),
                                          IconButton(
                                            iconSize: 18,
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.auto_fix_high_rounded),
                                            tooltip: 'بازسازی/رفع متن این درس',
                                            onPressed: () => _rebuildLesson(lesson),
                                          ),
                                          IconButton(
                                            iconSize: 18,
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.call_split_rounded),
                                            tooltip: 'تقسیم به دو درس',
                                            onPressed: () => _splitLesson(chapter, lesson),
                                          ),
                                          IconButton(
                                            iconSize: 18,
                                            visualDensity: VisualDensity.compact,
                                            icon: const Icon(Icons.swap_horiz_rounded),
                                            tooltip: 'جابجایی به فصل دیگر',
                                            onPressed: _chapters.length < 2 ? null : () => _moveLesson(chapter, lesson),
                                          ),
                                          IconButton(
                                            iconSize: 18,
                                            visualDensity: VisualDensity.compact,
                                            icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                                            tooltip: 'حذف',
                                            onPressed: () => _deleteLesson(chapter, lesson),
                                          ),
                                        ],
                                      ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
    );
  }
}
