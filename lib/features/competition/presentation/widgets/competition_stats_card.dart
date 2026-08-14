import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/competition_entities.dart';

/// «کارت آمار پویا» — دقت پاسخ‌دهی در امتحانات/آزمون‌ها + نمودار میلهٔ کوچکِ
/// امتیاز ۷ روز گذشته. بدون هیچ کتابخانهٔ نمودار خارجی (میله‌ها با
/// `Container` ساده کشیده می‌شوند) تا هیچ وابستگی تازه‌ای به پروژه اضافه نشود.
class CompetitionStatsCard extends StatelessWidget {
  final CompetitionStats stats;
  const CompetitionStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxPoints = stats.weeklyPointsSeries.fold<int>(1, (m, e) => e.points > m ? e.points : m);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_rounded, size: 18, color: scheme.tertiary),
              const SizedBox(width: 6),
              Text(context.tr('competition.statsTitle'),
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: scheme.onSurface)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatChip(
                  icon: Icons.gps_fixed_rounded,
                  label: context.tr('competition.accuracy'),
                  value: stats.accuracyPercent != null ? '${stats.accuracyPercent!.toStringAsFixed(0)}٪' : '—',
                  color: AppColors.green600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatChip(
                  icon: Icons.fact_check_rounded,
                  label: context.tr('competition.examsTaken'),
                  value: '${stats.examsPassed}/${stats.examsTaken}',
                  color: AppColors.orange600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(context.tr('competition.weeklyProgress'),
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: stats.weeklyPointsSeries.asMap().entries.map((e) {
                final ratio = maxPoints > 0 ? e.value.points / maxPoints : 0.0;
                final isToday = e.key == stats.weeklyPointsSeries.length - 1;
                final dayLabel = _weekdayShort(e.value.date);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${e.value.points}', style: TextStyle(fontSize: 8.5, color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.xs),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: ratio.clamp(0.04, 1.0).toDouble()),
                            duration: Duration(milliseconds: 600 + e.key * 80),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Container(
                              height: 40 * value,
                              decoration: BoxDecoration(
                                gradient: isToday ? AppColors.heroGradient : null,
                                color: isToday ? null : scheme.tertiaryContainer,
                                borderRadius: BorderRadius.circular(AppRadii.xs),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(dayLabel,
                            style: TextStyle(
                                fontSize: 8.5,
                                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                                color: isToday ? scheme.primary : scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.08, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }

  static String _weekdayShort(String isoDate) {
    try {
      final d = DateTime.parse(isoDate);
      const names = ['د', 'س', 'چ', 'پ', 'ج', 'ش', 'ی']; // شنبه..جمعه به ترتیب weekday (۱=دوشنبه در Dart)
      return names[(d.weekday - 1) % 7];
    } catch (_) {
      return '';
    }
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: scheme.onSurface)),
                Text(label, style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
