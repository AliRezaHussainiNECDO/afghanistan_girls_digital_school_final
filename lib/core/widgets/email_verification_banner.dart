import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/providers/auth_providers.dart';
import '../localization/app_localizations.dart';

/// بنر «ایمیل خود را تأیید کنید» — بالای داشبورد هر نقش نمایش داده می‌شود
/// تا وقتی کاربر روی لینکِ ایمیل‌شده کلیک نکرده است.
///
/// طبق تصمیم محصول: ورود آزاد است، اما این بنر با دکمهٔ «ارسال مجدد لینک»
/// همیشه دیده می‌شود تا کاربر ایمیلش را تأیید کند.
class EmailVerificationBanner extends ConsumerStatefulWidget {
  const EmailVerificationBanner({super.key});

  @override
  ConsumerState<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState
    extends ConsumerState<EmailVerificationBanner> {
  bool _sending = false;
  bool _sent = false;

  Future<void> _resend() async {
    setState(() => _sending = true);
    await ref.read(authSessionProvider.notifier).resendVerification();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authSessionProvider);
    // فقط برای کاربر واردشده‌ای که ایمیلش تأیید نشده.
    if (user == null || user.emailVerified) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(
            _sent ? Icons.mark_email_read_rounded : Icons.mark_email_unread_rounded,
            color: scheme.onTertiaryContainer,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _sent
                  ? context.tr('auth.verificationSent')
                  : context.tr('auth.verifyEmailBanner'),
              style: TextStyle(
                color: scheme.onTertiaryContainer,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
          if (!_sent)
            _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _resend,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                    child: Text(
                      context.tr('auth.resendVerification'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
        ],
      ),
    );
  }
}
