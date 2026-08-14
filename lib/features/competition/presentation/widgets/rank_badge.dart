import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../domain/entities/competition_entities.dart';
import 'competition_icons.dart';

/// نشان دایره‌ای گرادیانی یک مقام — قلب بصری «رقابت مکتب». هرجا مقام یک
/// شاگرد نمایش داده می‌شود (کارت من، جدول رتبه‌ها، فهرست مقام‌ها) از همین
/// یک ویجت استفاده می‌شود تا ظاهر یکدست بماند.
class RankBadge extends StatelessWidget {
  final RankTier tier;
  final double size;
  final bool glow;
  final bool animate;

  const RankBadge({
    super.key,
    required this.tier,
    this.size = 56,
    this.glow = false,
    this.animate = false,
  });

  @override
  Widget build(BuildContext context) {
    final from = colorFromHex(tier.colorFrom);
    final to = colorFromHex(tier.colorTo);

    Widget badge = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [from, to]),
        boxShadow: glow
            ? [
                BoxShadow(color: from.withValues(alpha: 0.55), blurRadius: size * 0.5, spreadRadius: size * 0.02),
              ]
            : null,
        border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: size * 0.035),
      ),
      child: Icon(competitionIconFor(tier.icon), color: Colors.white, size: size * 0.46),
    );

    if (animate) {
      badge = badge
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(end: 1.08, duration: 1400.ms, curve: Curves.easeInOut);
    }
    return badge;
  }
}

/// نسخهٔ کوچک برای ردیف‌های جدول رتبه‌ها — نشان + عدد رتبه در گوشهٔ آن.
class RankBadgeWithPosition extends StatelessWidget {
  final RankTier tier;
  final int position;
  final double size;

  const RankBadgeWithPosition({super.key, required this.tier, required this.position, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        RankBadge(tier: tier, size: size),
        Positioned(
          bottom: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
            ),
            child: Text('#$position', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }
}
