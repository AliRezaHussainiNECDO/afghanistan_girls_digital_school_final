import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/competition_entities.dart';
import 'competition_icons.dart';
import 'rank_badge.dart';

/// «نقشهٔ سه‌بعدیِ جادهٔ دانش» — طبق سند طراحی رقابت (بخش ۵). بعد از بررسی
/// پکیج `three_dart` (ورژن ۰.۰.۱۶، حدود ۳-۴ سال بدون به‌روزرسانی، وابسته به
/// `flutter_gl` که نیاز به تنظیمات native دارد) و تأیید کاربر، بجای موتور
/// سه‌بعدی واقعی، یک مسیر پیچانِ شبه‌سه‌بعدی/ایزومتریک با `CustomPainter`
/// ساخته شده: با گرادیان، سایه و درخشش عمق بصری القا می‌کند — بدون هیچ
/// وابستگی تازه یا ریسک ناپایداری در پروداکشن.
///
/// مسیر طیّ‌شده (تا مقام فعلی شاگرد) روشن/درخشان و مسیر پیشِ‌رو کم‌رنگ است؛
/// هر ۱۰ مقام یک لیگ را تشکیل می‌دهد که با یک بنر جدا نشان داده می‌شود.
class LearningRoadmap extends StatefulWidget {
  final List<RankTier> tiers;
  final int currentRankNo;

  const LearningRoadmap({super.key, required this.tiers, required this.currentRankNo});

  @override
  State<LearningRoadmap> createState() => _LearningRoadmapState();
}

class _LearningRoadmapState extends State<LearningRoadmap> {
  final _scrollController = ScrollController();

  static const double _stepY = 98;
  static const double _nodeSize = 50;
  static const double _nodeColWidth = 78;
  static const double _topPad = 64;
  static const double _bottomPad = 70;
  static const double _viewportHeight = 420;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!mounted || !_scrollController.hasClients || widget.tiers.isEmpty) return;
    final index = (widget.currentRankNo - 1).clamp(0, widget.tiers.length - 1);
    final targetY = _topPad + index * _stepY;
    final viewport = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final offset = (targetY - viewport / 2).clamp(0.0, maxScroll).toDouble();
    _scrollController.animateTo(offset, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  double _xFor(int i, double amplitude, double centerX) => centerX + amplitude * math.sin(i * (math.pi / 4));

  @override
  Widget build(BuildContext context) {
    final tiers = widget.tiers;
    if (tiers.isEmpty) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final totalHeight = _topPad + (tiers.length - 1) * _stepY + _bottomPad;

    return SizedBox(
      height: _viewportHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final centerX = width / 2;
          final amplitude = math.min(width * 0.30, 110.0);
          final positions = List.generate(
            tiers.length,
            (i) => Offset(_xFor(i, amplitude, centerX), _topPad + i * _stepY),
          );
          final double progressFraction = tiers.length <= 1
              ? 1.0
              : ((widget.currentRankNo - 1) / (tiers.length - 1)).clamp(0.0, 1.0).toDouble();

          final children = <Widget>[
            Positioned.fill(
              child: CustomPaint(
                painter: _RoadmapPathPainter(
                  positions: positions,
                  progressFraction: progressFraction,
                  activeColor: AppColors.orange500,
                  inactiveColor: scheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
            ),
          ];

          for (var i = 0; i < tiers.length; i++) {
            final tier = tiers[i];
            if (i == 0 || tiers[i - 1].leagueKey != tier.leagueKey) {
              children.add(_buildLeagueHeader(context, tier, positions[i].dy - _nodeSize / 2 - 34));
            }
            children.add(_buildNode(context, tier, positions[i]));
          }

          return Scrollbar(
            controller: _scrollController,
            child: SingleChildScrollView(
              controller: _scrollController,
              child: SizedBox(
                width: width,
                height: totalHeight,
                child: Stack(children: children),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLeagueHeader(BuildContext context, RankTier tier, double y) {
    return Positioned(
      top: math.max(0.0, y),
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [colorFromHex(tier.colorFrom), colorFromHex(tier.colorTo)]),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            boxShadow: AppShadows.soft,
          ),
          child: Text(
            tier.leagueTitleFa,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Widget _buildNode(BuildContext context, RankTier tier, Offset pos) {
    final scheme = Theme.of(context).colorScheme;
    final rankNo = tier.rankNo;
    final isCurrent = rankNo == widget.currentRankNo;
    final isLocked = rankNo > widget.currentRankNo;

    Widget badge = RankBadge(tier: tier, size: _nodeSize, glow: isCurrent, animate: isCurrent);
    if (isLocked) {
      badge = Opacity(
        opacity: 0.42,
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
          child: badge,
        ),
      );
    }

    final node = GestureDetector(
      onTap: () => _showTierSheet(context, tier, isLocked: isLocked),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              badge,
              Positioned(
                bottom: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: scheme.outlineVariant, width: 1),
                  ),
                  child: Text('#$rankNo', style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800)),
                ),
              ),
              if (isLocked)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                    child: Icon(Icons.lock_rounded, size: 11, color: scheme.onSurfaceVariant),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: _nodeColWidth,
            child: Text(
              tier.titleFa,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                color: isCurrent ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    return Positioned(
      left: pos.dx - _nodeColWidth / 2,
      top: pos.dy - _nodeSize / 2,
      child: SizedBox(width: _nodeColWidth, child: node),
    );
  }

  void _showTierSheet(BuildContext context, RankTier tier, {required bool isLocked}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  RankBadge(tier: tier, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tier.titleFa, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        Text(tier.leagueTitleFa, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoLine(
                icon: Icons.stars_rounded,
                label: ctx.tr('competition.roadmapPointsNeeded'),
                value: '${tier.minPoints}',
              ),
              if (tier.rewardLabelFa.isNotEmpty) ...[
                const SizedBox(height: 8),
                _InfoLine(
                  icon: Icons.card_giftcard_rounded,
                  label: ctx.tr('competition.roadmapReward'),
                  value: tier.rewardLabelFa,
                ),
              ],
              if (isLocked) ...[
                const SizedBox(height: 12),
                Text(
                  ctx.tr('competition.roadmapLockedHint'),
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoLine({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 16, color: scheme.tertiary),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))),
      ],
    );
  }
}

/// مسیرِ پیچانِ جاده — با منحنی‌های Bezier نرم بین گره‌ها؛ بخش طی‌شده (از
/// ابتدای مسیر تا مقام فعلی) با `PathMetric` دقیقاً از روی همان مسیر اصلی
/// استخراج و با رنگ درخشان کشیده می‌شود تا همیشه کاملاً روی خط پایه منطبق
/// بماند.
class _RoadmapPathPainter extends CustomPainter {
  final List<Offset> positions;
  final double progressFraction;
  final Color activeColor;
  final Color inactiveColor;

  _RoadmapPathPainter({
    required this.positions,
    required this.progressFraction,
    required this.activeColor,
    required this.inactiveColor,
  });

  Path _buildPath() {
    final path = Path();
    if (positions.isEmpty) return path;
    path.moveTo(positions.first.dx, positions.first.dy);
    for (var i = 1; i < positions.length; i++) {
      final prev = positions[i - 1];
      final curr = positions[i];
      final controlY = (prev.dy + curr.dy) / 2;
      path.cubicTo(prev.dx, controlY, curr.dx, controlY, curr.dx, curr.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (positions.length < 2) return;
    final path = _buildPath();

    final basePaint = Paint()
      ..color = inactiveColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, basePaint);

    final metrics = path.computeMetrics().toList();
    var total = 0.0;
    for (final m in metrics) {
      total += m.length;
    }
    final targetLength = total * progressFraction.clamp(0.0, 1.0);

    final activePath = Path();
    var consumed = 0.0;
    for (final m in metrics) {
      if (consumed >= targetLength) break;
      final remaining = targetLength - consumed;
      final take = remaining >= m.length ? m.length : remaining;
      activePath.addPath(m.extractPath(0, take), Offset.zero);
      consumed += m.length;
    }

    final glowPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(activePath, glowPaint);

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(activePath, activePaint);
  }

  @override
  bool shouldRepaint(covariant _RoadmapPathPainter oldDelegate) {
    return oldDelegate.positions != positions ||
        oldDelegate.progressFraction != progressFraction ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}
