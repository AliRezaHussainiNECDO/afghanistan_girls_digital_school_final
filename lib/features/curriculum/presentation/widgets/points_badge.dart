import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';

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
            context.tr('points.totalAndLevel', {'total': '$pointsTotal', 'level': '$pointsLevel'}),
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

/// نسخهٔ پویا و تزئینیِ امتیاز فعالیت — مخصوص کارت خوش‌آمدگویی خانهٔ شاگرد
/// (طبق درخواست کاربر: «امتیازات پویاتر و زیباتر»). برخلاف [PointsBadge]
/// ساده، این ویجت واقعاً از دادهٔ «پیشرفت تا سطح بعدی» استفاده می‌کند —
/// دادهٔ آن قبلاً روی سرور محاسبه می‌شد (`getPointsSummary`) ولی هرگز به
/// این صفحه نمی‌رسید، پس شاگرد هیچ‌وقت نمی‌دید «چند امتیاز تا سطح بعدی»
/// مانده؛ همان بخش دیگرِ رفع اشکال «منطق امتیازات».
///
/// سه عنصر پویا دارد: نشان طلایی با تپش ملایم دائمی، عددِ امتیاز که با
/// انیمیشنِ شمارشی از صفر بالا می‌رود، و نوار پیشرفت تا سطح بعدی که با
/// همان حس به‌آرامی پر می‌شود.
class StudentPointsHero extends StatelessWidget {
  final int pointsTotal;
  final int pointsLevel;
  final String pointsLevelTitleFa;
  final int? nextLevelAt;
  final String? nextLevelTitleFa;
  final double progressToNextPercent;

  const StudentPointsHero({
    super.key,
    required this.pointsTotal,
    required this.pointsLevel,
    required this.pointsLevelTitleFa,
    this.nextLevelAt,
    this.nextLevelTitleFa,
    this.progressToNextPercent = 0,
  });

  @override
  Widget build(BuildContext context) {
    final atMaxLevel = nextLevelTitleFa == null || nextLevelAt == null;
    final remaining = atMaxLevel ? 0 : (nextLevelAt! - pointsTotal).clamp(0, nextLevelAt!);
    final progress = (progressToNextPercent / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                gradient: AppColors.goldCelebrationGradient,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.military_tech_rounded, size: 14, color: Colors.white),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scaleXY(end: 1.15, duration: 1100.ms, curve: Curves.easeInOut),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: pointsTotal),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    '$value',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 19),
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(context.tr('points.unit'),
                      style:
                          TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(context.tr('points.levelAndTitle', {'level': '$pointsLevel', 'title': pointsLevelTitleFa}),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        atMaxLevel
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 13, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(context.tr('points.maxLevelReached'),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92), fontSize: 10.5, fontWeight: FontWeight.w700)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: progress),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.24),
                        valueColor: const AlwaysStoppedAnimation(AppColors.gold500),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.tr('points.remainingToNextLevel',
                        {'remaining': '$remaining', 'title': nextLevelTitleFa ?? ''}),
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85), fontSize: 10.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
      ],
    );
  }
}
