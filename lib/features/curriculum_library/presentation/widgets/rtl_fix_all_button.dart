import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/network/network_providers.dart';
import '../providers/curriculum_library_providers.dart';

/// دکمهٔ یک‌کلیکی برای رفع اصلاحیِ متنِ **همهٔ** کتاب‌های قبلاً آپلودشده
/// (در همهٔ صنف‌ها و همهٔ مضامین) که به‌خاطر اشکال قدیمیِ استخراج PDF،
/// نویسه‌های هر کلمه‌شان معکوس ذخیره شده بود (مثلاً «ایمیک» به‌جای «کیمیا»).
/// طبق درخواست صریح کاربر که این رفع نباید نیازمند حذف/آپلود دستیِ تک‌تک
/// کتاب‌ها باشد؛ این دکمه یک‌بار Endpoint سرور
/// (`POST /admin/curriculum-library/books/fix-rtl-text-all`) را صدا می‌زند
/// که خودش برای هر کتاب تشخیص می‌دهد آیا واقعاً معکوس بوده (کاملاً ایمن —
/// کتاب‌های از قبل درست دست‌نخورده می‌مانند) و در صورت نیاز فصل/درس‌های آن
/// را هم بازسازی می‌کند.
class RtlFixAllButton extends ConsumerStatefulWidget {
  const RtlFixAllButton({super.key});

  @override
  ConsumerState<RtlFixAllButton> createState() => _RtlFixAllButtonState();
}

class _RtlFixAllButtonState extends ConsumerState<RtlFixAllButton> {
  bool _running = false;

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final data = await ref
          .read(apiClientProvider)
          .post('/admin/curriculum-library/books/fix-rtl-text-all');
      final map = Map<String, dynamic>.from(data as Map? ?? {});
      final total = (map['totalBooks'] as num?)?.toInt() ?? 0;
      final changed = (map['changedCount'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(changed > 0
              ? 'بررسی شد: از $total کتاب، متن $changed کتاب معکوس بود و اصلاح/بازسازی شد ✓'
              : 'بررسی شد: از $total کتاب، هیچ‌کدام مشکل متن معکوس نداشتند.'),
          duration: const Duration(seconds: 6),
        ),
      );
      // نصاب همهٔ مضامین ممکن است تغییر کرده باشد — کش کتابخانه را باطل می‌کنیم
      // تا هر بخش (آپلود کتاب، نصاب شاگردان، معلم هوشمند) داده‌های تازه بگیرد.
      ref.invalidate(booksForSubjectProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در رفع اصلاحی: $e')),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.tertiaryContainer,
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
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4, color: scheme.onTertiaryContainer),
                    )
                  : Icon(Icons.auto_fix_high_rounded, color: scheme.onTertiaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رفع متن‌های معکوس (همهٔ کتاب‌ها)',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, color: scheme.onTertiaryContainer)),
                    Text(
                      _running
                          ? 'در حال بررسی و اصلاح کتاب‌های همهٔ صنف‌ها و مضامین…'
                          : 'کتاب‌هایی که متن‌شان نامنظم/بی‌مفهوم نمایش داده می‌شود را یک‌جا اصلاح می‌کند',
                      style: TextStyle(fontSize: 12, color: scheme.onTertiaryContainer),
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
