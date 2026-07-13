import 'package:flutter/material.dart';

import '../../app/theme/design_tokens.dart';

/// دکمهٔ اصلی مشترک — پیل گرادیانی با انیمیشن فشردن، طبق سیستم طراحی جدید.
class AppPrimaryButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final Gradient? gradient;

  const AppPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.gradient,
  });

  @override
  State<AppPrimaryButton> createState() => _AppPrimaryButtonState();
}

class _AppPrimaryButtonState extends State<AppPrimaryButton> {
  double _scale = 1;
  bool _hovering = false;

  bool get _enabled => widget.onPressed != null && !widget.loading;

  @override
  Widget build(BuildContext context) {
    final gradient = widget.gradient ?? AppColors.heroGradient;

    return MouseRegion(
      cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTapDown: _enabled ? (_) => setState(() => _scale = 0.97) : null,
        onTapUp: _enabled ? (_) => setState(() => _scale = 1) : null,
        onTapCancel: _enabled ? () => setState(() => _scale = 1) : null,
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedScale(
          scale: _hovering && _enabled ? _scale * 1.015 : _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedOpacity(
          opacity: _enabled || widget.loading ? 1 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(AppRadii.pill),
              boxShadow: _hovering && _enabled
                  ? [
                      ...AppShadows.warm,
                      BoxShadow(
                        color: AppShadows.warm.first.color.withValues(alpha: 0.35),
                        blurRadius: 32,
                        offset: const Offset(0, 14),
                      ),
                    ]
                  : AppShadows.warm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.loading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                  )
                else ...[
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          ),
        ),
      ),
    );
  }
}
