import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/competition_entities.dart';
import 'rank_badge.dart';

/// کارت بزرگِ بالای صفحهٔ رقابت — مقام فعلی، امتیاز کل، فاصله تا صدرنشین،
/// نوار پیشرفت تا مقام بعدی، و شعلهٔ فعالیت پیوسته. طراحی «فوق‌العاده مدرن»
/// طبق درخواست کاربر: گرادیان زنده + انیمیشن‌های ظریف پیوسته (نه فقط
/// یک‌باره) تا صفحه همیشه «زنده» به‌نظر برسد.
class CompetitionHeroCard extends StatelessWidget {
  final CompetitionStatus status;

  const CompetitionHeroCard({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final hasNext = status.nextTier != null;
    final progress = (status.progressToNextTierPercent / 100).clamp(0.0, 1.0).toDouble();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        gradient: AppColors.sunriseGradient,
        borderRadius: BorderRadius.circular(AppRadii.xl),
        boxShadow: AppShadows.warm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RankBadge(tier: status.tier, size: 68, glow: true, animate: true),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('competition.myRank'),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(status.tier.titleFa,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: status.totalPoints),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Text('$value',
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 4),
                        Text(context.tr('points.unit'),
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                        const SizedBox(width: 10),
                        Icon(Icons.emoji_events_rounded, size: 14, color: Colors.white.withValues(alpha: 0.85)),
                        const SizedBox(width: 3),
                        Text(
                          '#${status.globalPosition}',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StreakChip(days: status.streakCurrent),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.24),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasNext
                ? context.tr('competition.progressToNextTier', {
                    'remaining': '${status.pointsToNextTier}',
                    'title': status.nextTier!.titleFa,
                  })
                : context.tr('competition.maxTierReached'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              children: [
                Icon(
                  status.isRankOne ? Icons.workspace_premium_rounded : Icons.flag_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    status.isRankOne
                        ? context.tr('competition.alreadyRankOne')
                        : context.tr('competition.pointsToRankOne', {'points': '${status.pointsToRankOneGlobal ?? 0}'}),
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        // درخشش ملایم و پیوسته روی کل کارت — طبق کامنت بالای فایل: کارت باید
        // «همیشه زنده» به‌نظر برسد، نه فقط لحظهٔ بارگذاری. یک نوار نور کم‌رنگ
        // هر چند ثانیه از روی گرادیان سرمی‌خورد.
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 3200.ms, delay: 900.ms, color: Colors.white.withValues(alpha: 0.16));
  }
}

class _StreakChip extends StatelessWidget {
  final int days;
  const _StreakChip({required this.days});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.local_fire_department_rounded, color: AppColors.gold300, size: 26)
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(end: 1.18, duration: 900.ms, curve: Curves.easeInOut),
        const SizedBox(height: 2),
        Text('$days', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        Text(context.tr('competition.streakLabel'),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 9)),
      ],
    );
  }
}
