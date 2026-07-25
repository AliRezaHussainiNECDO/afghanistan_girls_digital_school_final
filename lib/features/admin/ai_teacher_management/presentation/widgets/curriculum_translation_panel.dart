import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/network_providers.dart';

/// همان ۱۰ مضمون رسمی — هماهنگ با `CORE_SUBJECTS` بک‌اند
/// (`backend/src/routes/aiCurriculum.ts`) و `_coreSubjects` در
/// `ai_curriculum_generate_panel.dart`.
const _translationSubjects = <({String id, String nameFa})>[
  (id: 'math', nameFa: 'ریاضی'),
  (id: 'physics', nameFa: 'فزیک'),
  (id: 'chemistry', nameFa: 'کیمیا'),
  (id: 'biology', nameFa: 'بیولوژی'),
  (id: 'english', nameFa: 'انگلیسی'),
  (id: 'dari_lit', nameFa: 'ادبیات دری'),
  (id: 'history', nameFa: 'تاریخ'),
  (id: 'geography', nameFa: 'جغرافیه'),
  (id: 'islamic', nameFa: 'تعلیمات اسلامی'),
  (id: 'computer', nameFa: 'کمپیوتر ساینس'),
];

/// ═══════ پنل «ترجمهٔ نصاب» (اول پشتو) — طبق درخواست صاحب پروژه ═══════════
///
/// مدیر صنف+مضمون را انتخاب می‌کند؛ درخت فصل‌ها/درس‌ها (همان
/// `/admin/curriculum/tree` که پنل «تولید هوشمند نصاب» هم استفاده می‌کند)
/// نمایش داده می‌شود. کنار هر فصل/درس یکی از سه حالت دیده می‌شود:
///   • بدون ترجمه → دکمهٔ «تولید با AI» (پیش‌نویس می‌سازد، `status=draft`).
///   • پیش‌نویس آماده → دکمهٔ «مرور/ویرایش» (مدیر می‌تواند متن را اصلاح و
///     سپس منتشر کند — تا منتشر نشود هیچ شاگردی نمی‌بیند).
///   • منتشرشده ✓ → همان دکمهٔ «مرور/ویرایش» برای اصلاح بعدی در دسترس می‌ماند.
class CurriculumTranslationPanel extends ConsumerStatefulWidget {
  const CurriculumTranslationPanel({super.key});

  @override
  ConsumerState<CurriculumTranslationPanel> createState() => _CurriculumTranslationPanelState();
}

class _CurriculumTranslationPanelState extends ConsumerState<CurriculumTranslationPanel> {
  static const _language = 'ps'; // فعلاً فقط پشتو — ساختار آمادهٔ زبان بعدی.

  int _grade = 7;
  String _subjectId = _translationSubjects.first.id;
  bool _loadingTree = false;
  bool _treeLoadedOnce = false;
  List<Map<String, dynamic>> _tree = const [];

  /// entityId → ردیف ترجمه (id, status, title, body) — یک‌بار برای کل
  /// درخت فعلی خوانده می‌شود (نه یک تماس جدا برای هر فصل/درس).
  final Map<String, Map<String, dynamic>> _chapterTranslations = {};
  final Map<String, Map<String, dynamic>> _lessonTranslations = {};

  /// entityId هایی که همین الان دارند تولید/ذخیره می‌شوند (نمایش چرخش بارگذاری).
  final Set<String> _busy = {};

  Future<void> _loadAll() async {
    setState(() => _loadingTree = true);
    try {
      final api = ref.read(apiClientProvider);
      final treeData = await api.get('/admin/curriculum/tree', queryParameters: {'grade': _grade, 'subject': _subjectId});
      final chapters =
          (treeData['chapters'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

      final chapterTr = await api.get('/admin/curriculum/translations',
          queryParameters: {'entityType': 'chapter', 'language': _language});
      final lessonTr = await api.get('/admin/curriculum/translations',
          queryParameters: {'entityType': 'lesson', 'language': _language});

      if (!mounted) return;
      setState(() {
        _tree = chapters;
        _chapterTranslations
          ..clear()
          ..addEntries((chapterTr['translations'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .map((e) => MapEntry(e['entityId'] as String, e)));
        _lessonTranslations
          ..clear()
          ..addEntries((lessonTr['translations'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .map((e) => MapEntry(e['entityId'] as String, e)));
      });
    } catch (_) {
      if (mounted) setState(() => _tree = const []);
    } finally {
      if (mounted) {
        setState(() {
          _loadingTree = false;
          _treeLoadedOnce = true;
        });
      }
    }
  }

  Future<void> _generate(String entityType, String entityId) async {
    setState(() => _busy.add(entityId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.post('/admin/curriculum/translate',
          data: {'entityType': entityType, 'entityId': entityId, 'language': _language});
      final translation = Map<String, dynamic>.from((data['translation'] as Map?) ?? {});
      if (!mounted) return;
      setState(() {
        if (entityType == 'chapter') {
          _chapterTranslations[entityId] = translation;
        } else {
          _lessonTranslations[entityId] = translation;
        }
      });
      messenger.showSnackBar(SnackBar(content: Text(context.tr('adminTranslation.draftReady'))));
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
        backgroundColor: e.type == ApiErrorType.rateLimited
            ? Theme.of(context).colorScheme.tertiaryContainer
            : null,
        content: Text(e.message),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy.remove(entityId));
    }
  }

  Future<void> _openReviewDialog({
    required String entityType,
    required String entityId,
    required String sourceTitleFa,
    String? sourceBodyFa,
  }) async {
    final existing = entityType == 'chapter' ? _chapterTranslations[entityId] : _lessonTranslations[entityId];
    if (existing == null) return;
    final titleController = TextEditingController(text: existing['title'] as String? ?? '');
    final bodyController = TextEditingController(text: existing['body'] as String? ?? '');
    final isLesson = entityType == 'lesson';
    final isPublished = existing['status'] == 'published';

    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('adminTranslation.reviewTitle')),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.tr('adminTranslation.sourceDariLabel'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(sourceTitleFa, style: const TextStyle(fontSize: 12.5)),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: context.tr('adminTranslation.translatedTitleLabel'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (isLesson) ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: bodyController,
                    maxLines: 12,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      labelText: context.tr('adminTranslation.translatedBodyLabel'),
                      border: const OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      isPublished ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                      size: 15,
                      color: isPublished ? AppColors.green600 : AppColors.orange600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isPublished
                          ? context.tr('adminTranslation.statusPublished')
                          : context.tr('adminTranslation.statusDraft'),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isPublished ? AppColors.green600 : AppColors.orange600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(context.tr('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save_draft'),
            child: Text(context.tr('adminTranslation.saveDraft')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'publish'),
            child: Text(context.tr('adminTranslation.publish')),
          ),
        ],
      ),
    );

    if (action == null || action == 'cancel' || !mounted) return;
    final translationId = existing['id'] as String;
    setState(() => _busy.add(entityId));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.patch('/admin/curriculum/translations/$translationId', data: {
        'title': titleController.text.trim(),
        if (isLesson) 'body': bodyController.text.trim(),
        'status': action == 'publish' ? 'published' : 'draft',
      });
      final updated = Map<String, dynamic>.from((data['translation'] as Map?) ?? {});
      if (!mounted) return;
      setState(() {
        if (entityType == 'chapter') {
          _chapterTranslations[entityId] = updated;
        } else {
          _lessonTranslations[entityId] = updated;
        }
      });
      messenger.showSnackBar(SnackBar(
        content: Text(action == 'publish'
            ? context.tr('adminTranslation.publishedSnackbar')
            : context.tr('adminTranslation.draftSavedSnackbar')),
      ));
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy.remove(entityId));
    }
  }

  Widget _statusChip(BuildContext context, String entityType, String entityId, String sourceTitleFa, String? sourceBody) {
    final translation = entityType == 'chapter' ? _chapterTranslations[entityId] : _lessonTranslations[entityId];
    final isBusy = _busy.contains(entityId);

    if (isBusy) {
      return const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (translation == null) {
      return TextButton.icon(
        onPressed: () => _generate(entityType, entityId),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: const EdgeInsets.symmetric(horizontal: 8)),
        icon: const Icon(Icons.auto_awesome_rounded, size: 15),
        label: Text(context.tr('adminTranslation.generateButton'), style: const TextStyle(fontSize: 11)),
      );
    }
    final isPublished = translation['status'] == 'published';
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: () => _openReviewDialog(
        entityType: entityType,
        entityId: entityId,
        sourceTitleFa: sourceTitleFa,
        sourceBodyFa: sourceBody,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isPublished ? AppColors.green600 : AppColors.orange600).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPublished ? Icons.check_circle_rounded : Icons.edit_note_rounded,
                size: 13, color: isPublished ? AppColors.green600 : AppColors.orange600),
            const SizedBox(width: 4),
            Text(
              isPublished ? context.tr('adminTranslation.statusPublished') : context.tr('adminTranslation.statusDraft'),
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isPublished ? AppColors.green600 : AppColors.orange600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
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
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                child: const Icon(Icons.translate_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('adminTranslation.title'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(context.tr('adminTranslation.subtitle'),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  initialValue: _grade,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAiCurriculum.gradeLabel'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    isDense: true,
                  ),
                  items: [for (var g = 7; g <= 12; g++) DropdownMenuItem(value: g, child: Text('$g'))],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _grade = v);
                    _loadAll();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _subjectId,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAiCurriculum.subjectLabel'),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    isDense: true,
                  ),
                  items: [
                    for (final s in _translationSubjects) DropdownMenuItem(value: s.id, child: Text(s.nameFa)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _subjectId = v);
                    _loadAll();
                  },
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: context.tr('common.retry'),
                onPressed: _loadingTree ? null : _loadAll,
                icon: _loadingTree
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_treeLoadedOnce && !_loadingTree)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(context.tr('adminTranslation.pickHint'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            )
          else if (_treeLoadedOnce && _tree.isEmpty && !_loadingTree)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(context.tr('adminAiCurriculum.treeEmpty'),
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            )
          else
            ...List.generate(_tree.length, (i) {
              final ch = _tree[i];
              final chapterId = ch['id'] as String;
              final chapterTitle = '${ch['title_fa']}';
              final lessons =
                  (ch['lessons'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
              return ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsetsDirectional.only(start: 16),
                title: Row(
                  children: [
                    Expanded(
                        child: Text(chapterTitle, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
                    _statusChip(context, 'chapter', chapterId, chapterTitle, null),
                  ],
                ),
                children: [
                  for (final l in lessons)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text('${l['title_fa']}', style: const TextStyle(fontSize: 12.5)),
                          ),
                          _statusChip(context, 'lesson', l['id'] as String, '${l['title_fa']}', null),
                        ],
                      ),
                    ),
                ],
              ).animate().fadeIn(delay: (40 * i).ms, duration: 200.ms);
            }),
        ],
      ),
    );
  }
}
