import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/competition_entities.dart';
import 'rank_badge.dart';

/// یک ردیف در جدول رتبه‌ها (بعد از سکوی ۳ نفر اول) — ردیف خودِ کاربر با
/// رنگ برند برجسته می‌شود تا فوراً موقعیت خودش را در رقابت پیدا کند.
class LeaderboardTile extends StatelessWidget {
  final LeaderboardEntry entry;
  final bool isMe;
  final int index;

  /// موقعیت این کاربر در تازه‌سازیِ *قبلی* جدول — اگر داده شود و با موقعیت
  /// فعلی فرق کند، یک نشانگر ▲/▼ کوچک نمایش داده می‌شود (طبق درخواست کاربر:
  /// «زنده‌بودن» جدول باید حتی در تغییرِ رتبه هم حس شود، نه فقط در بارگذاری
  /// اول). اختیاری — بدون آن رفتار قبلی دقیقاً حفظ می‌شود.
  final int? previousPosition;

  const LeaderboardTile({
    super.key,
    required this.entry,
    required this.isMe,
    required this.index,
    this.previousPosition,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: isMe ? Border.all(color: scheme.primary, width: 1.4) : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text('${entry.position}',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: scheme.onSurfaceVariant)),
          ),
          const SizedBox(width: 8),
          RankBadge(tier: entry.tier, size: 36),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? '${entry.displayName} · ${context.tr('competition.you')}' : entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scheme.onSurface),
                ),
                Text(entry.tier.titleFa, style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (previousPosition != null && previousPosition != entry.position) _PositionDelta(previous: previousPosition!, current: entry.position),
          Text(
            context.tr('competition.pointsShort', {'points': '${entry.totalPoints}'}),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: scheme.tertiary),
          ),
        ],
      ),
    ).animate(delay: (20 * index).ms).fadeIn(duration: 260.ms).slideX(begin: 0.08, end: 0, duration: 260.ms);
  }
}

/// نشانگر کوچک تغییرِ رتبه — عدد کوچک‌تر یعنی بهتر، پس رفتن از #۵ به #۳
/// «بهبود» (سبز، فلش بالا) و برعکس «افت» (سرخ، فلش پایین) است.
class _PositionDelta extends StatelessWidget {
  final int previous;
  final int current;
  const _PositionDelta({required this.previous, required this.current});

  @override
  Widget build(BuildContext context) {
    final improved = current < previous;
    final delta = (previous - current).abs();
    final color = improved ? AppColors.green600 : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(AppRadii.pill)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(improved ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded, size: 14, color: color),
          Text('$delta', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scaleXY(begin: 0.7, end: 1, duration: 300.ms, curve: Curves.easeOutBack);
  }
}
