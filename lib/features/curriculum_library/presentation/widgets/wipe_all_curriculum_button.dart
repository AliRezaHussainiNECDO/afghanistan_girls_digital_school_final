import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/network/network_providers.dart';
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
  static const String _confirmPhrase = 'پاک کن';

  Future<void> _confirmAndRun() async {
    final controller = TextEditingController();
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber_rounded, color: scheme.error, size: 36),
        title: const Text('پاک‌سازی کامل نصاب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'این کار همهٔ کتاب‌های کتابخانه، فصل‌ها و درس‌های ساخته‌شده در همهٔ صنف‌ها و مضامین را برای همیشه حذف می‌کند. شاگردان تا آپلود دوبارهٔ کتاب‌ها، هیچ درسی نخواهند دید. این عملیات غیرقابل بازگشت است.',
            ),
            const SizedBox(height: 14),
            Text('برای تأیید، عبارت «$_confirmPhrase» را دقیقاً تایپ کنید:',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                hintText: 'پاک کن',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () => Navigator.pop(ctx, controller.text.trim() == _confirmPhrase),
            child: const Text('پاک‌سازی کامل'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      if (mounted && controller.text.trim().isNotEmpty && controller.text.trim() != _confirmPhrase) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('عبارت تأیید درست وارد نشد — پاک‌سازی انجام نشد.')));
      }
      return;
    }

    setState(() => _running = true);
    try {
      final data = await ref.read(apiClientProvider).post(
        '/admin/curriculum-library/wipe-all',
        data: {'confirm': 'WIPE_ALL_CURRICULUM'},
      );
      final map = Map<String, dynamic>.from(data as Map? ?? {});
      final deleted = Map<String, dynamic>.from(map['deleted'] as Map? ?? {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'نصاب پاک شد: ${deleted['books'] ?? 0} کتاب، ${deleted['chapters'] ?? 0} فصل، ${deleted['lessons'] ?? 0} درس حذف شد. اکنون می‌توانید کتاب‌ها را دوباره آپلود کنید.'),
          duration: const Duration(seconds: 7),
        ),
      );
      ref.invalidate(booksForSubjectProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطا در پاک‌سازی: $e')));
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
                    Text('پاک‌سازی کامل نصاب و شروع از صفر',
                        style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onErrorContainer)),
                    Text(
                      'همهٔ کتاب‌ها/فصل‌ها/درس‌های فعلی حذف می‌شود — غیرقابل بازگشت',
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
