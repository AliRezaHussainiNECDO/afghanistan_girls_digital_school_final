import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

/// افکت جشن‌گرفتن — یک بارانِ کانفتی رنگارنگ که برای تشویق دختران در
/// لحظات موفقیت (ثبت‌نام سمینار، تکمیل امتحان، باز شدن دستاورد) نمایش
/// داده می‌شود. با [CelebrationOverlay.of(context).burst()] از هر جای اپ
/// قابل‌فراخوانی است.
class CelebrationOverlay extends StatefulWidget {
  final Widget child;
  const CelebrationOverlay({super.key, required this.child});

  static CelebrationOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<CelebrationOverlayState>();
  }

  @override
  State<CelebrationOverlay> createState() => CelebrationOverlayState();
}

class CelebrationOverlayState extends State<CelebrationOverlay> {
  late final ConfettiController _controller =
      ConfettiController(duration: const Duration(milliseconds: 1400));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// یک بارانِ کوتاه کانفتی از بالای صفحه پخش می‌کند.
  void burst() => _controller.play();

  Path _star(Size size) {
    const points = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.2;
    final path = Path();
    const degreesPerStep = (pi * 2) / points;
    const halfStep = degreesPerStep / 2;
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < pi * 2; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * cos(step), halfWidth + externalRadius * sin(step));
      path.lineTo(halfWidth + internalRadius * cos(step + halfStep),
          halfWidth + internalRadius * sin(step + halfStep));
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _controller,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 24,
                maxBlastForce: 18,
                minBlastForce: 8,
                gravity: 0.25,
                emissionFrequency: 0.0,
                shouldLoop: false,
                createParticlePath: _star,
                colors: const [
                  AppColors.orange500,
                  AppColors.gold500,
                  AppColors.green500,
                  AppColors.orange400,
                  Colors.white,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
