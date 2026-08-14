import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/competition_entities.dart';
import 'rank_badge.dart';

/// سکوی نفرات اول تا سوم — قلب دیداری جدول رتبه‌ها. نفر اول در وسط و
/// بلندتر (طبق قرارداد بصری شناخته‌شدهٔ سکوهای قهرمانی) با یک تاج و درخشش
/// طلایی، تا «مبارزه برای مقام اول» به‌روشنی حس شود.
class LeaderboardPodium extends StatelessWidget {
  final List<LeaderboardEntry> top3;
  final String? myStudentId;

  const LeaderboardPodium({super.key, required this.top3, this.myStudentId});

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) return const SizedBox.shrink();
    final first = top3.isNotEmpty ? top3[0] : null;
    final second = top3.length > 1 ? top3[1] : null;
    final third = top3.length > 2 ? top3[2] : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
              child: second == null
                  ? const SizedBox.shrink()
                  : _PodiumColumn(entry: second, height: 92, delayMs: 150, isMe: second.studentId == myStudentId)),
          Expanded(
              child: first == null
                  ? const SizedBox.shrink()
                  : _PodiumColumn(entry: first, height: 118, delayMs: 0, isFirst: true, isMe: first.studentId == myStudentId)),
          Expanded(
              child: third == null
                  ? const SizedBox.shrink()
                  : _PodiumColumn(entry: third, height: 72, delayMs: 300, isMe: third.studentId == myStudentId)),
        ],
      ),
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final LeaderboardEntry entry;
  final double height;
  final int delayMs;
  final bool isFirst;
  final bool isMe;

  const _PodiumColumn({
    required this.entry,
    required this.height,
    required this.delayMs,
    this.isFirst = false,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isFirst)
          const Icon(Icons.emoji_events_rounded, color: AppColors.gold500, size: 26)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .slideY(begin: 0, end: -0.16, duration: 1000.ms, curve: Curves.easeInOut),
        Container(
          padding: EdgeInsets.all(isMe ? 2.5 : 0),
          decoration: isMe ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: scheme.primary, width: 2)) : null,
          child: RankBadge(tier: entry.tier, size: isFirst ? 60 : 48, glow: isFirst),
        ),
        const SizedBox(height: 6),
        Text(
          entry.displayName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: isFirst ? 12.5 : 11.5,
              color: isMe ? scheme.primary : scheme.onSurface),
        ),
        Text(
          '${entry.totalPoints}',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 10.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isFirst
                  ? [AppColors.gold300, AppColors.gold600]
                  : [scheme.tertiaryContainer, scheme.tertiaryContainer.withValues(alpha: 0.6)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.md)),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 6),
          child: Text('#${entry.position}',
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: isFirst ? Colors.white : scheme.onTertiaryContainer)),
        ),
      ],
    );

    return column
        .animate(delay: delayMs.ms)
        .fadeIn(duration: 420.ms)
        .slideY(begin: 0.16, end: 0, duration: 420.ms, curve: Curves.easeOutCubic);
  }
}
