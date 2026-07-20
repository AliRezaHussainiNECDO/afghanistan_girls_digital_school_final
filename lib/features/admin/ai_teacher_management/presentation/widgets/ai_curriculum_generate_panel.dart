import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/network/api_client.dart';
import '../../../../../core/network/network_providers.dart';
import '../../../../curriculum/presentation/providers/curriculum_providers.dart';

/// ═══════ پنل «تولید هوشمند نصاب» (جایگزین کامل سیستم قدیمی PDF) ═══════════
///
/// منبع مطلق محتوا خودِ Gemini است (Pure AI Generation): مدیر فقط صنف (۷..۱۲)
/// و مضمون اساسی را از درپ‌داون‌های پویا انتخاب و «تولید هوشمند» را می‌زند؛
/// سرور (`POST /admin/curriculum/ai-generate`) با ResponseSchema کل ساختار
/// درختی کتاب را ساخته و در دیتابیس تزریق می‌کند. هیچ آپلود فایل/PDF لازم
/// نیست. درختوارهٔ تولیدشده + وضعیت قفل پیش‌فرض هر فصل/درس همین‌جا برای
/// نظارت مدیر نمایش داده می‌شود.
class AiCurriculumGeneratePanel extends ConsumerStatefulWidget {
  const AiCurriculumGeneratePanel({super.key});

  @override
  ConsumerState<AiCurriculumGeneratePanel> createState() => _AiCurriculumGeneratePanelState();
}

/// مضامین اساسی مجاز (هماهنگ با CORE_SUBJECTS بک‌اند — routes/aiCurriculum.ts).
/// ⚠️ شناسه‌ها دقیقاً مطابق seed جدول `subjects` (مهاجرت 0003) — لیست کامل
/// ۱۰ مضمون رسمی صنف‌های ۷ تا ۱۲ (شناسه‌های قبلی `dari`/`pashto` در دیتابیس
/// وجود نداشتند و تولیدشان در داشبورد شاگرد ظاهر نمی‌شد).
const _coreSubjects = <({String id, String nameFa})>[
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

class _AiCurriculumGeneratePanelState extends ConsumerState<AiCurriculumGeneratePanel> {
  int _grade = 7;
  String _subjectId = _coreSubjects.first.id;
  bool _generating = false;
  bool _loadingTree = false;
  List<Map<String, dynamic>> _tree = const [];
  bool _treeLoadedOnce = false;

  String get _subjectNameFa =>
      _coreSubjects.firstWhere((s) => s.id == _subjectId).nameFa;

  Future<void> _loadTree() async {
    setState(() => _loadingTree = true);
    try {
      final data = await ref.read(apiClientProvider).get(
        '/admin/curriculum/tree',
        queryParameters: {'grade': _grade, 'subject': _subjectId},
      );
      final chapters = (data['chapters'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => _tree = chapters);
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

  Future<void> _generate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('adminAiCurriculum.generateButton')),
        content: Text(context.tr('adminAiCurriculum.generateConfirm',
            {'subject': _subjectNameFa, 'grade': '$_grade'})),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('adminAiCurriculum.generateButton'))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final data = await ref.read(apiClientProvider).post(
        '/admin/curriculum/ai-generate',
        data: {'gradeNumber': _grade, 'subjectId': _subjectId},
      );
      final m = Map<String, dynamic>.from(data as Map? ?? {});
      messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 6),
        content: Text(context.tr('adminAiCurriculum.generateSuccess', {
          'book': '${m['bookTitle'] ?? _subjectNameFa}',
          'chapters': '${m['chaptersCreated'] ?? 0}',
          'lessons': '${m['lessonsCreated'] ?? 0}',
        })),
      ));
      // نصاب شاگردان تغییر کرده — کش نصاب باطل می‌شود تا همه‌جا همگام بماند.
      ref.invalidate(chaptersProvider);
      ref.invalidate(lessonsProvider);
      ref.invalidate(lessonProvider);
      await _loadTree();
    } on ApiException catch (e) {
      // مدیریت صریح 429 (سهمیهٔ رایگان Gemini) — پیام محترمانه، بدون کرش.
      messenger.showSnackBar(SnackBar(
        backgroundColor: e.type == ApiErrorType.rateLimited
            ? Theme.of(context).colorScheme.tertiaryContainer
            : null,
        content: Text(
          e.message,
          style: e.type == ApiErrorType.rateLimited
              ? TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer)
              : null,
        ),
        duration: const Duration(seconds: 6),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
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
                decoration: const BoxDecoration(
                    gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('adminAiCurriculum.title'),
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(context.tr('adminAiCurriculum.subtitle'),
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── درپ‌داون‌های پویا: صنف (۷..۱۲) + مضمون اساسی همان صنف ──
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _grade,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAiCurriculum.gradeLabel'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md)),
                    isDense: true,
                  ),
                  items: [
                    for (var g = 7; g <= 12; g++)
                      DropdownMenuItem(value: g, child: Text('$g')),
                  ],
                  onChanged: _generating
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _grade = v);
                          _loadTree();
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _subjectId,
                  decoration: InputDecoration(
                    labelText: context.tr('adminAiCurriculum.subjectLabel'),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md)),
                    isDense: true,
                  ),
                  items: [
                    for (final s in _coreSubjects)
                      DropdownMenuItem(value: s.id, child: Text(s.nameFa)),
                  ],
                  onChanged: _generating
                      ? null
                      : (v) {
                          if (v == null) return;
                          setState(() => _subjectId = v);
                          _loadTree();
                        },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _generating ? null : _generate,
            icon: _generating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome_rounded),
            label: Text(context.tr('adminAiCurriculum.generateButton')),
          ),
          const SizedBox(height: 14),
          // ── درختوارهٔ تولیدشده + وضعیت قفل پیش‌فرض (نظارت مدیر) ──
          Row(
            children: [
              Icon(Icons.account_tree_rounded, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(context.tr('adminAiCurriculum.treePreviewTitle'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              IconButton(
                tooltip: context.tr('common.retry'),
                visualDensity: VisualDensity.compact,
                onPressed: _loadingTree ? null : _loadTree,
                icon: _loadingTree
                    ? const SizedBox(
                        width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh_rounded, size: 20),
              ),
            ],
          ),
          if (!_treeLoadedOnce && !_loadingTree)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(context.tr('adminAiCurriculum.treeEmpty'),
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
              final lessons = (ch['lessons'] as List? ?? [])
                  .map((e) => Map<String, dynamic>.from(e as Map))
                  .toList();
              final chUnlocked = ch['default_unlocked'] == true;
              return ExpansionTile(
                dense: true,
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsetsDirectional.only(start: 16),
                leading: Icon(
                  chUnlocked ? Icons.lock_open_rounded : Icons.lock_rounded,
                  size: 18,
                  color: chUnlocked ? AppColors.green600 : scheme.outline,
                ),
                title: Text('${ch['title_fa']}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  chUnlocked
                      ? context.tr('adminAiCurriculum.defaultUnlocked')
                      : context.tr('adminAiCurriculum.defaultLocked'),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                ),
                children: [
                  for (final l in lessons)
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        l['default_unlocked'] == true
                            ? Icons.play_circle_outline_rounded
                            : Icons.lock_outline_rounded,
                        size: 16,
                        color: l['default_unlocked'] == true
                            ? AppColors.green600
                            : scheme.outline,
                      ),
                      title: Text('${l['title_fa']}', style: const TextStyle(fontSize: 12.5)),
                      trailing: Text(
                        l['content_generated'] == true
                            ? context.tr('adminAiCurriculum.contentReady')
                            : context.tr('adminAiCurriculum.contentPending'),
                        style: TextStyle(
                          fontSize: 10.5,
                          color: l['content_generated'] == true
                              ? AppColors.green600
                              : scheme.tertiary,
                        ),
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

/// ═══════ کارت «رفتار پایهٔ معلم هوشمند» — نظارت/Overwrite پرامپت پایه ═══════
/// مدیر متن کامل System Prompt حالت «تمرکز مطلق بر درس» را می‌بیند و می‌تواند
/// آن را بازنویسی کند — بدون دستکاری هیچ عملکرد دیگر (Endpointهای
/// GET/PATCH `/admin/ai-teacher/base-prompt`).
class AiBasePromptCard extends ConsumerStatefulWidget {
  const AiBasePromptCard({super.key});

  @override
  ConsumerState<AiBasePromptCard> createState() => _AiBasePromptCardState();
}

class _AiBasePromptCardState extends ConsumerState<AiBasePromptCard> {
  Future<void> _open() async {
    String current = '';
    try {
      final data = await ref.read(apiClientProvider).get('/admin/ai-teacher/base-prompt');
      current = (data['basePrompt'] as String?) ?? '';
    } catch (_) {}
    if (!mounted) return;
    final controller = TextEditingController(text: current);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('adminAiCurriculum.basePromptTitle')),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.tr('adminAiCurriculum.basePromptResetHint'),
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 10,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.tr('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.tr('common.save'))),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await ref
          .read(apiClientProvider)
          .patch('/admin/ai-teacher/base-prompt', data: {'basePrompt': controller.text.trim()});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('adminAiCurriculum.basePromptSaved'))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(Icons.policy_rounded, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('adminAiCurriculum.basePromptTitle'),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                    Text(context.tr('adminAiCurriculum.basePromptSubtitle'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
