import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/competition_entities.dart';
import 'competition_icons.dart';

/// کارت یک میشن روزانه — مثل [MissionCard] ولی با یک حالت اضافه: «قفل»
/// (وقتی این میشن به میشن دیگری از همان روز نیاز دارد که هنوز دریافت
/// نشده) — طبق «قفل زنجیره‌ای» سند طراحی رقابت.
class DailyQuestCard extends StatelessWidget {
  final DailyQuest quest;
  final bool claiming;
  final VoidCallback? onClaim;

  const DailyQuestCard({super.key, required this.quest, required this.claiming, this.onClaim});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = quest.locked;
    final claimable = quest.claimable;

    return Opacity(
      opacity: locked ? 0.55 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: quest.claimed
              ? scheme.surfaceContainerHighest.withValues(alpha: 0.35)
              : (claimable ? AppColors.green100.withValues(alpha: 0.35) : scheme.surface),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: claimable ? AppColors.green600.withValues(alpha: 0.5) : scheme.outlineVariant.withValues(alpha: 0.5),
            width: claimable ? 1.4 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: quest.claimed ? scheme.surfaceContainerHighest : AppColors.orange100,
              ),
              child: Icon(
                locked
                    ? Icons.lock_rounded
                    : (quest.claimed ? Icons.check_rounded : competitionIconFor(quest.icon)),
                color: quest.claimed ? scheme.onSurfaceVariant : AppColors.orange600,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(quest.titleFa, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: scheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(quest.descriptionFa,
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant), maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (!locked) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            child: LinearProgressIndicator(
                              value: quest.progressPercent,
                              minHeight: 5,
                              backgroundColor: scheme.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(quest.completed ? AppColors.green500 : scheme.tertiary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text('${quest.progressCount}/${quest.targetCount}',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (quest.claimed)
              const Icon(Icons.verified_rounded, color: AppColors.green500, size: 18)
            else if (claimable)
              SizedBox(
                height: 30,
                child: ElevatedButton(
                  onPressed: claiming ? null : onClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.green600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
                    elevation: 0,
                  ),
                  child: claiming
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('+${quest.pointsReward}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleXY(end: 1.06, duration: 900.ms, curve: Curves.easeInOut)
            else
              Text('+${quest.pointsReward}', style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
