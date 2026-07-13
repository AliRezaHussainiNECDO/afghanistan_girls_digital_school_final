import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// یک دایرهٔ گرادیانی محو که به‌آرامی بالا/پایین شناور می‌شود — برای عمق
/// و زندگی‌بخشیدن به پس‌زمینهٔ صفحات (ورود، خوش‌آمدید، داشبورد) بدون
/// مزاحمت برای محتوای اصلی.
class FloatingBlob extends StatelessWidget {
  final Gradient gradient;
  final double size;
  final double opacity;
  final bool reverse;
  final Duration duration;

  const FloatingBlob({
    super.key,
    required this.gradient,
    required this.size,
    this.opacity = 0.14,
    this.reverse = false,
    this.duration = const Duration(milliseconds: 4200),
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
        ),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(
            begin: reverse ? 14 : -14,
            end: reverse ? -14 : 14,
            duration: duration,
            curve: Curves.easeInOut,
          ),
    );
  }
}
