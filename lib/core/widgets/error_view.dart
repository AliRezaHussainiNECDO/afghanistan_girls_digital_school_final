import 'package:flutter/material.dart';
import '../localization/app_localizations.dart';
import 'app_primary_button.dart';

class ErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sentiment_dissatisfied_rounded, size: 34, color: scheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              message ?? context.tr('common.error'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: AppPrimaryButton(
                  label: context.tr('common.retry'),
                  onPressed: onRetry,
                  icon: Icons.refresh_rounded,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
