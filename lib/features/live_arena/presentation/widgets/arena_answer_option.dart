import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../app/theme/design_tokens.dart';

/// یک گزینهٔ پاسخ — چهار حالت بصری: عادی، انتخاب‌شده (منتظر نتیجه)،
/// درست (بعد از reveal)، غلط (بعد از reveal، فقط اگر همین را انتخاب کرده بود).
class ArenaAnswerOption extends StatelessWidget {
  final String label; // «الف»/«ب»/«ج»/«د» یا A/B/C/D
  final String text;
  final bool selected;
  final bool revealed;
  final bool isCorrectAnswer;
  final bool locked; // بعد از ارسال پاسخ یا در فاز reveal — دیگر قابل لمس نیست
  final VoidCallback? onTap;

  const ArenaAnswerOption({
    super.key,
    required this.label,
    required this.text,
    required this.selected,
    required this.revealed,
    required this.isCorrectAnswer,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Color bg = scheme.surfaceContainerLow;
    Color border = scheme.outlineVariant;
    Color fg = scheme.onSurface;

    if (revealed && isCorrectAnswer) {
      bg = AppColors.green500.withValues(alpha: 0.16);
      border = AppColors.green500;
      fg = AppColors.green700;
    } else if (revealed && selected && !isCorrectAnswer) {
      bg = AppColors.danger.withValues(alpha: 0.14);
      border = AppColors.danger;
      fg = AppColors.danger;
    } else if (selected) {
      bg = scheme.primaryContainer;
      border = scheme.primary;
      fg = scheme.onPrimaryContainer;
    }

    Widget card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: border, width: selected || (revealed && isCorrectAnswer) ? 2 : 1),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: border.withValues(alpha: 0.18), shape: BoxShape.circle),
            child: Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: fg)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: fg))),
          if (revealed && isCorrectAnswer) const Icon(Icons.check_circle_rounded, color: AppColors.green600, size: 20),
          if (revealed && selected && !isCorrectAnswer) const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 20),
        ],
      ),
    );

    if (revealed && isCorrectAnswer) {
      card = card.animate().shimmer(duration: 700.ms, color: AppColors.green300.withValues(alpha: 0.5));
    }

    return GestureDetector(
      onTap: locked ? null : onTap,
      child: card,
    );
  }
}
