import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../providers/auth_providers.dart';

/// بازیابی رمز عبور در دو مرحله (بخش ۳.۴ سند):
///   ۱) کاربر ایمیلش را وارد می‌کند → سرور کد ۶ رقمی به ایمیل می‌فرستد.
///   ۲) کاربر کد + رمز جدید را وارد می‌کند → رمز تغییر کرده و همهٔ نشست‌های
///      قبلی باطل می‌شوند؛ کاربر به صفحهٔ ورود برمی‌گردد.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _submitting = false;
  bool _codeSent = false; // مرحلهٔ ۲ فعال است؟
  bool _done = false; // رمز با موفقیت تغییر کرد؟
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  /// مرحلهٔ ۱ — درخواست ارسال کد به ایمیل.
  Future<void> _sendCode() async {
    if (_email.text.trim().isEmpty || !_email.text.contains('@')) {
      setState(() => _error = context.tr('common.required'));
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    await ref.read(authSessionProvider.notifier).forgotPassword(_email.text.trim());
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _codeSent = true; // طبق بخش ۳.۴: پیام یکسان صرف‌نظر از وجود ایمیل
    });
  }

  /// مرحلهٔ ۲ — تغییر رمز با کد ۶ رقمی.
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await ref.read(authSessionProvider.notifier).resetPassword(
          email: _email.text.trim(),
          code: _code.text.trim(),
          newPassword: _newPassword.text,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      if (ok) {
        _done = true;
      } else {
        _error = ref.read(authSessionProvider.notifier).lastError ??
            context.tr('common.error');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('auth.forgotPassword'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradientWarm,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.warm,
                      ),
                      child: Icon(
                        _done ? Icons.check_circle_rounded : Icons.lock_reset_rounded,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_done)
                    // ── حالت پایانی: موفقیت ─────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.verified_rounded,
                              color: scheme.onSecondaryContainer, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('auth.passwordChanged'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.onSecondaryContainer),
                          ),
                          const SizedBox(height: 14),
                          AppPrimaryButton(
                            label: context.tr('auth.loginButton'),
                            onPressed: () => context.go('/login'),
                            icon: Icons.arrow_forward_rounded,
                          ),
                        ],
                      ),
                    )
                  else ...[
                    // ── مرحلهٔ ۱: ایمیل ─────────────────────────────────
                    TextFormField(
                      controller: _email,
                      enabled: !_codeSent,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: context.tr('auth.email'),
                        prefixIcon: const Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (v) => (v == null || !v.contains('@'))
                          ? context.tr('common.required')
                          : null,
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mark_email_read_rounded,
                                color: scheme.onSecondaryContainer, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                context.tr('auth.resetCodeSent'),
                                style: TextStyle(
                                    color: scheme.onSecondaryContainer, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // ── مرحلهٔ ۲: کد + رمز جدید ───────────────────────
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 20, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: context.tr('auth.resetCodeLabel'),
                          prefixIcon: const Icon(Icons.pin_rounded),
                          counterText: '',
                        ),
                        validator: (v) => (v == null || v.trim().length != 6)
                            ? context.tr('common.required')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _newPassword,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: context.tr('auth.newPassword'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 8)
                            ? context.tr('auth.passwordTooShort')
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _confirmPassword,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: context.tr('auth.confirmNewPassword'),
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                        ),
                        validator: (v) => (v != _newPassword.text)
                            ? context.tr('auth.passwordsDontMatch')
                            : null,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: scheme.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline_rounded,
                                size: 18, color: scheme.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style:
                                      TextStyle(color: scheme.error, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    AppPrimaryButton(
                      label: _codeSent
                          ? context.tr('auth.resetPasswordButton')
                          : context.tr('common.submit'),
                      loading: _submitting,
                      onPressed: _codeSent ? _resetPassword : _sendCode,
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _submitting ? null : _sendCode,
                        child: Text(context.tr('auth.resendVerification')),
                      ),
                    ],
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
