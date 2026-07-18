import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/network_providers.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../providers/curriculum_library_providers.dart';

/// دکمهٔ رفع اشکالِ «کتاب را از مدیریت پاک کردم اما هنوز در بخش شاگردان
/// است» — قبلاً حذف یک کتاب فقط ردیف کتابخانه را پاک می‌کرد، در حالی که
/// فصل/درس‌های منتشرشدهٔ همان کتاب (که نصاب داشبورد شاگردان دقیقاً از
/// آن‌ها می‌خواند) دست‌نخورده می‌ماندند. این اشکال در Endpoint حذف رفع شد؛
/// این دکمه برای پاک‌سازیِ **باقیماندهٔ** کتاب‌هایی است که پیش از این رفع
/// اشکال حذف شده بودند — یک‌بار زدن کافی است.
class CleanupOrphanedButton extends ConsumerStatefulWidget {
  const CleanupOrphanedButton({super.key});

  @override
  ConsumerState<CleanupOrphanedButton> createState() => _CleanupOrphanedButtonState();
}

class _CleanupOrphanedButtonState extends ConsumerState<CleanupOrphanedButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final data =
          await ref.read(apiClientProvider).post('/admin/curriculum-library/cleanup-orphaned-chapters');
      final map = Map<String, dynamic>.from(data as Map? ?? {});
      final chapters = (map['chaptersRemoved'] as num?)?.toInt() ?? 0;
      final lessons = (map['lessonsRemoved'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chapters > 0
              ? context.tr('cleanupOrphaned.successWithCounts', {'chapters': '$chapters', 'lessons': '$lessons'})
              : context.tr('cleanupOrphaned.nothingToClean')),
          duration: const Duration(seconds: 6),
        ),
      );
      ref.invalidate(booksForSubjectProvider);
      ref.invalidate(chaptersProvider);
      ref.invalidate(lessonsProvider);
      ref.invalidate(lessonProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.tr('cleanupOrphaned.cleanupErrorWithReason', {'error': '$e'}))));
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.secondaryContainer,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: _running ? null : _run,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _running
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2.4, color: scheme.onSecondaryContainer),
                    )
                  : Icon(Icons.cleaning_services_rounded, color: scheme.onSecondaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('cleanupOrphaned.buttonTitle'),
                        style: TextStyle(fontWeight: FontWeight.w800, color: scheme.onSecondaryContainer)),
                    Text(
                      context.tr('cleanupOrphaned.buttonSubtitle'),
                      style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
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
