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

  const LeaderboardTile({super.key, required this.entry, required this.isMe, required this.index});

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
          Text(
            context.tr('competition.pointsShort', {'points': '${entry.totalPoints}'}),
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: scheme.tertiary),
          ),
        ],
      ),
    ).animate(delay: (20 * index).ms).fadeIn(duration: 260.ms).slideX(begin: 0.08, end: 0, duration: 260.ms);
  }
}
