import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../app/theme/design_tokens.dart';

/// نشان/کارت کوچک آمار — یک ظاهر واحد برای معلومات اضافیِ نقش‌محور در
/// سراسر برنامه: سربرگ منوی کناری (Drawer) هر داشبورد + ردیف آمار صفحهٔ
/// پروفایل. طبق درخواست کاربر («معلومات اضافی شاگرد» در سربرگ منو + طراحی
/// یکدست و مدرن)، این ویجت به‌جای تکرار کد در چند فایل، یک‌بار تعریف و در
/// هرجا با دادهٔ واقعیِ همان نقش (صنف/امتیاز شاگرد، فرزندان متصل والد،
/// شاگردان تحت مدیریت مدیر، سمینارهای استاد) استفاده می‌شود.
class InfoStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// روی زمینهٔ گرادیانی/تیره (سربرگ Drawer، کارت گرادیانی پروفایل) یا سطح
  /// عادی (کارت‌های سفید/خنثی).
  final bool light;

  /// نسخهٔ فشرده‌تر — مناسب ردیف باریک سربرگ Drawer.
  final bool dense;

  const InfoStatChip({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.light = false,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = light ? Colors.white : scheme.onSurface;
    final subFg = light ? Colors.white.withValues(alpha: 0.82) : scheme.onSurfaceVariant;
    final bg = light ? Colors.white.withValues(alpha: 0.16) : scheme.surfaceContainerLowest;
    final iconBg = light ? Colors.white.withValues(alpha: 0.24) : scheme.primaryContainer;
    final iconColor = light ? Colors.white : scheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14, vertical: dense ? 6 : 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: light ? Colors.white.withValues(alpha: 0.26) : scheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dense ? 22 : 32,
            height: dense ? 22 : 32,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: dense ? 12 : 17, color: iconColor),
          ),
          SizedBox(width: dense ? 6 : 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: fg, fontWeight: FontWeight.w800, fontSize: dense ? 11.5 : 14.5),
              ),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: subFg, fontSize: dense ? 9 : 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideX(begin: 0.08, end: 0, duration: 260.ms, curve: Curves.easeOutCubic);
  }
}

/// اسکلت بارگذاریِ [InfoStatChip] — تا وقتی معلومات نقش‌محور از سرور
/// می‌رسد (مثلاً امتیاز شاگرد یا تعداد فرزندان والد)، سربرگ به‌جای خالی
/// پریدن، یک بلوک محوِ پویا نشان می‌دهد.
class InfoStatChipSkeleton extends StatelessWidget {
  final bool light;
  final bool dense;
  const InfoStatChipSkeleton({super.key, this.light = false, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = light ? Colors.white.withValues(alpha: 0.14) : scheme.surfaceContainerLowest;
    return Container(
      width: dense ? 96 : 128,
      height: dense ? 34 : 52,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadii.md)),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fade(begin: 0.35, end: 0.9, duration: 650.ms, curve: Curves.easeInOut);
  }
}
