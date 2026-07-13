import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../localization/app_localizations.dart';
import '../../app/theme/design_tokens.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: AppColors.sunriseGradient,
              shape: BoxShape.circle,
              boxShadow: AppShadows.warm,
            ),
            child: const CircularProgressIndicator(strokeWidth: 3, color: Colors.white),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(begin: 1, end: 1.08, duration: 900.ms, curve: Curves.easeInOut),
          const SizedBox(height: 16),
          Text(
            context.tr('common.loading'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 900.ms).then().fadeOut(
              delay: 300.ms, duration: 900.ms),
        ],
      ),
    );
  }
}
