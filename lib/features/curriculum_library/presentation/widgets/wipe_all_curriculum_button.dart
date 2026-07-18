import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/network_providers.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../providers/curriculum_library_providers.dart';

/// دکمهٔ «پاک‌سازی کامل نصاب و شروع از صفر» — طبق درخواست صریح کاربر که
/// می‌خواهد همهٔ کتاب‌ها/فصل‌ها/درس‌های فعلی حذف شوند تا با منطق تازه از نو
/// آپلود شود. این عملیات **کاملاً غیرقابل‌بازگشت** است، به همین دلیل با دو
/// لایهٔ محافظت طراحی شده: (۱) یک دیالوگ هشدار صریح که تعداد دقیق کتاب/فصل/
/// درس فعلی را نشان می‌دهد، (۲) الزام تایپ دقیق عبارت تأیید — نه فقط یک
/// دکمهٔ «بله» ساده که ممکن است تصادفی زده شود.
class WipeAllCurriculumButton extends ConsumerStatefulWidget {
  const WipeAllCurriculumButton({super.key});

  @override
  ConsumerState<WipeAllCurriculumButton> createState() => _WipeAllCurriculumButtonState();
}

class _WipeAllCurriculumButtonState extends ConsumerState<WipeAllCurriculumButton> {
  bool _running = false;
  String get _confirmPhrase => context.tr('wipeAll.confirmPhrase');

  Future<void> _confirmAndRun() async {
    final controller = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    // رفع اشکال «هیچ درسی وجود ندارد اما امتیازات موجود است»: پاک‌سازی
    // نصاب عمداً امتیاز/تاریخچهٔ یادگیری شاگردان را دست‌نخورده می‌گذارد
    // (امتیاز یک دستاورد تاریخی است، نه بخشی از نصاب — حذف کتاب نباید
    // امتیاز قبلاً کسب‌شده را از شاگرد بگیرد). اما در پاک‌سازی‌های آزمایشی
    // که واقعاً «شروع از صفر» مدنظر است، امتیازهای قدیمیِ باقی‌مانده
    // گیج‌کننده به نظر می‌رسند — این چک‌باکس اختیاری (پیش‌فرض خاموش) همان
    // را هم پاک می‌کند.
    var resetLearningData = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 36),
          title: Text(ctx.tr('wipeAll.dialogTitle')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ctx.tr('wipeAll.warningBody')),
                const SizedBox(height: 10),
                CheckboxListTile(
                  value: resetLearningData,
                  onChanged: (v) => setDialogState(() => resetLearningData = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    ctx.tr('wipeAll.resetLearningTitle'),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    ctx.tr('wipeAll.resetLearningSubtitle'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 8),
                Text(ctx.tr('wipeAll.confirmPhraseInstruction', {'phrase': _confirmPhrase}),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    isDense: true,
                    hintText: _confirmPhrase,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('common.cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: scheme.error),
              onPressed: () => Navigator.pop(ctx, controller.text.trim() == _confirmPhrase),
              child: Text(ctx.tr('wipeAll.confirmButton')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      if (mounted && controller.text.trim().isNotEmpty && controller.text.trim() != _confirmPhrase) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('wipeAll.wrongPhraseNotice'))));
      }
      return;
    }

    setState(() => _running = true);
    try {
      final data = await ref.read(apiClientProvider).post(
        '/admin/curriculum-library/wipe-all',
        data: {'confirm': 'WIPE_ALL_CURRICULUM', 'resetLearningData': resetLearningData},
      );
      final map = Map<String, dynamic>.from(data as Map? ?? {});
      final deleted = Map<String, dynamic>.from(map['deleted'] as Map? ?? {});
      if (!mounted) return;
      final learningNote = resetLearningData
          ? context.tr('wipeAll.learningResetNote')
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              context.tr('wipeAll.successNotice', {
            'books': '${deleted['books'] ?? 0}',
            'chapters': '${deleted['chapters'] ?? 0}',
            'lessons': '${deleted['lessons'] ?? 0}',
            'learningNote': learningNote,
          })),
          duration: const Duration(seconds: 7),
        ),
      );
      ref.invalidate(booksForSubjectProvider);
      // نصاب شاگردان (فصل‌ها/درس‌ها) هم باید بلافاصله خالی نشان داده شود —
      // نه فقط بعد از خروج/ورود دوباره به برنامه. با autoDispose این
      // Providerها معمولاً خودشان با خروج از صفحه تازه می‌شوند، ولی برای
      // هر صفحه‌ای که همین الان (مثلاً پیش‌نمایش مدیر) باز مانده، invalidate
      // صریح لازم است.
      ref.invalidate(chaptersProvider);
      ref.invalidate(lessonsProvider);
      ref.invalidate(lessonProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('wipeAll.wipeErrorWithReason', {'error': '$e'}))));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.errorContainer,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: _running ? null : _confirmAndRun,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _running
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: scheme.onErrorContainer),
                    )
                  : Icon(Icons.delete_forever_rounded, color: scheme.onErrorContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('wipeAll.buttonTitle'),
                        style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onErrorContainer)),
                    Text(
                      context.tr('wipeAll.buttonSubtitle'),
                      style: TextStyle(fontSize: 12, color: scheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
