import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../domain/entities/live_arena_entities.dart';

/// جدول امتیازِ لحظه‌ایِ کوچک — بعد از هر سؤال دوباره می‌سازد؛ چون
/// `AnimatedSwitcher` با کلیدِ `studentId` هر ردیف را جدا رصد می‌کند، تغییر
/// امتیاز/جای‌به‌جایی رتبه با یک محوشدگی/جابه‌جایی نرم به چشم می‌آید، نه
/// یک‌بارهٔ خشک.
class ArenaMiniLeaderboard extends StatelessWidget {
  final List<ArenaStanding> standings;
  final String? myStudentId;
  final int maxRows;

  const ArenaMiniLeaderboard({super.key, required this.standings, this.myStudentId, this.maxRows = 6});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = standings.take(maxRows).toList();
    if (rows.isEmpty) return const SizedBox.shrink();

    return Column(
      children: rows.map((s) {
        final isMe = s.studentId == myStudentId;
        return Container(
          key: ValueKey(s.studentId),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isMe ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: isMe ? Border.all(color: scheme.primary, width: 1.2) : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text('#${s.position}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: isMe ? FontWeight.w800 : FontWeight.w600, fontSize: 12.5, color: scheme.onSurface),
                ),
              ),
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: s.score),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) =>
                    Text('$value', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12.5, color: AppColors.orange600)),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms);
      }).toList(),
    );
  }
}
