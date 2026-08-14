import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/competition_entities.dart';
import 'competition_icons.dart';

/// کارت یک میشن (چالش) — پیشرفت واقعیِ همان بخش از برنامه (درس/کارخانگی/
/// امتحان/…) را نشان می‌دهد و وقتی تکمیل شد، دکمهٔ «دریافت پاداش» فعال
/// می‌شود. طراحی این کارت عمداً با حس «صندوق جایزه» است تا شاگرد برای باز
/// کردنش تشویق شود.
class MissionCard extends StatelessWidget {
  final CompetitionMission mission;
  final bool claiming;
  final VoidCallback? onClaim;

  const MissionCard({super.key, required this.mission, required this.claiming, this.onClaim});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = mission.completed;
    final claimable = mission.claimable;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: mission.claimed
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : (claimable ? AppColors.gold300.withValues(alpha: 0.18) : scheme.surface),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: claimable ? AppColors.gold600.withValues(alpha: 0.55) : scheme.outlineVariant.withValues(alpha: 0.5),
          width: claimable ? 1.4 : 1,
        ),
        boxShadow: claimable ? AppShadows.soft : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: mission.claimed
                  ? null
                  : const LinearGradient(colors: [AppColors.orange400, AppColors.orange600]),
              color: mission.claimed ? scheme.surfaceContainerHighest : null,
            ),
            child: Icon(
              mission.claimed ? Icons.check_rounded : competitionIconFor(mission.icon),
              color: mission.claimed ? scheme.onSurfaceVariant : Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(mission.titleFa, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(mission.descriptionFa,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        child: LinearProgressIndicator(
                          value: mission.progressPercent,
                          minHeight: 6,
                          backgroundColor: scheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation(done ? AppColors.green500 : scheme.tertiary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${mission.progressCount}/${mission.targetCount}',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _RewardOrClaim(mission: mission, claiming: claiming, onClaim: onClaim),
        ],
      ),
    );
  }
}

class _RewardOrClaim extends StatelessWidget {
  final CompetitionMission mission;
  final bool claiming;
  final VoidCallback? onClaim;
  const _RewardOrClaim({required this.mission, required this.claiming, this.onClaim});

  @override
  Widget build(BuildContext context) {
    if (mission.claimed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, color: AppColors.green500, size: 20),
          const SizedBox(height: 2),
          Text('+${mission.pointsReward}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      );
    }
    if (mission.claimable) {
      return SizedBox(
        height: 34,
        child: ElevatedButton(
          onPressed: claiming ? null : onClaim,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.gold600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
            elevation: 0,
          ),
          child: claiming
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(context.tr('competition.missionClaim'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.06, duration: 900.ms, curve: Curves.easeInOut);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.stars_rounded, color: Theme.of(context).colorScheme.outline, size: 18),
        const SizedBox(height: 2),
        Text('+${mission.pointsReward}', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
