import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';

/// نوار پیشرفت یک مضمون/فصل — یک ظاهر واحد که هم در بخش فصل‌های شاگرد
/// (منبع حقیقتِ اصلی پیشرفت درسی) و هم در خلاصهٔ والدین و جزئیات شاگرد در
/// پنل مدیر استفاده می‌شود، تا منطق و نمایش پیشرفت درسی در همهٔ داشبوردها
/// یکسان باشد (طبق درخواست صریح کاربر).
class SubjectProgressBar extends StatelessWidget {
  /// برچسب اختیاری بالای نوار (مثلاً نام مضمون یا «پیشرفت کلی»).
  final String? label;

  /// درصد پیشرفت — بین ۰ تا ۱۰۰.
  final double percent;

  /// نسخهٔ فشرده (بدون برچسب/درصد بزرگ) — مناسب برای ردیف‌های فهرست.
  final bool compact;

  /// وقتی روی زمینهٔ گرادیانِ رنگی/تیره قرار می‌گیرد (سفید + نیمه‌شفاف).
  final bool light;

  /// رنگ دلخواه نوار (در غیر این صورت خودکار بر اساس تکمیل/اصلی انتخاب می‌شود).
  final Color? barColor;

  const SubjectProgressBar({
    super.key,
    this.label,
    required this.percent,
    this.compact = false,
    this.light = false,
    this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final clamped = percent.clamp(0, 100).toDouble();
    final resolvedBarColor =
        barColor ?? (light ? Colors.white : (clamped >= 100 ? AppColors.green600 : scheme.primary));
    final trackColor = light ? Colors.white.withValues(alpha: 0.28) : scheme.outlineVariant.withValues(alpha: 0.4);
    final textColor = light ? Colors.white : scheme.onSurfaceVariant;
    final percentColor = light ? Colors.white : resolvedBarColor;

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: LinearProgressIndicator(
        value: clamped / 100,
        minHeight: compact ? 5 : 8,
        backgroundColor: trackColor,
        valueColor: AlwaysStoppedAnimation(resolvedBarColor),
      ),
    );

    if (label == null) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: compact ? 11 : 12.5, fontWeight: FontWeight.w600, color: textColor),
                ),
              ),
              Text(
                '${clamped.toStringAsFixed(0)}%',
                style: TextStyle(fontSize: compact ? 11 : 12.5, fontWeight: FontWeight.w800, color: percentColor),
              ),
            ],
          ),
        ),
        bar,
      ],
    );
  }
}
