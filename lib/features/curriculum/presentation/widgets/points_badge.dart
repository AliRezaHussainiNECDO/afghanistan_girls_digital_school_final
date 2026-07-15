import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';

/// نشان امتیاز فعالیت (Gamification) — طبق `backend/src/lib/progress.ts`
/// (`getPointsSummary`). در همهٔ داشبوردها (شاگرد/والدین/مدیر) با همین یک
/// ظاهر نمایش داده می‌شود تا منطق امتیازدهی برای کاربر یکدست باشد.
class PointsBadge extends StatelessWidget {
  final int pointsTotal;
  final int pointsLevel;
  final String pointsLevelTitleFa;

  /// وقتی روی زمینهٔ گرادیانِ رنگی/تیره قرار می‌گیرد.
  final bool light;

  /// نسخهٔ فشرده — بدون عنوان سطح، مناسب ردیف‌های کوچک.
  final bool compact;

  const PointsBadge({
    super.key,
    required this.pointsTotal,
    required this.pointsLevel,
    required this.pointsLevelTitleFa,
    this.light = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = light ? Colors.white : scheme.onSurface;
    final bg = light ? Colors.white.withValues(alpha: 0.18) : scheme.tertiaryContainer.withValues(alpha: 0.5);
    final iconColor = light ? Colors.white : scheme.tertiary;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.military_tech_rounded, size: compact ? 14 : 16, color: iconColor),
          const SizedBox(width: 4),
          Text(
            '$pointsTotal امتیاز · سطح $pointsLevel',
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: compact ? 10.5 : 12),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            Text(
              '($pointsLevelTitleFa)',
              style: TextStyle(color: fg.withValues(alpha: 0.85), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
