import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/auth/saved_credentials_store.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/floating_blob.dart';
import '../../domain/entities/app_user.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _submitting = false;
  bool _obscure = true;
  bool _rememberMe = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  /// پر کردن خودکار فرم اگر کاربر قبلاً «مرا به خاطر بسپار» را فعال کرده باشد.
  Future<void> _loadSavedCredentials() async {
    final saved = await SavedCredentialsStore.load();
    if (saved == null || !mounted) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = saved.email;
      _passwordController.text = saved.password;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await ref
        .read(authSessionProvider.notifier)
        .login(_emailController.text.trim(), _passwordController.text);
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      // پیام دقیق سرور (مثلاً «حساب مسدود است» یا خطای شبکه) اگر موجود بود،
      // وگرنه پیام عمومی «ایمیل یا رمز اشتباه است».
      final serverMessage = ref.read(authSessionProvider.notifier).lastError;
      setState(() => _error = serverMessage ?? context.tr('auth.invalidCredentials'));
      return;
    }
    // «مرا به خاطر بسپار»: فقط پس از ورودِ موفق ذخیره/پاک می‌شود.
    if (_rememberMe) {
      await SavedCredentialsStore.save(
          _emailController.text.trim(), _passwordController.text);
    } else {
      await SavedCredentialsStore.clear();
    }
    if (!mounted) return;
    _redirectAfterLogin();
  }

  void _redirectAfterLogin() {
    final user = ref.read(authSessionProvider);
    if (user == null) return;
    switch (user.role) {
      case AppUserRole.superAdmin:
        context.go(AppRoutes.adminDashboard);
        break;
      case AppUserRole.student:
        context.go(AppRoutes.studentHome);
        break;
      case AppUserRole.parent:
        context.go(AppRoutes.parentDashboard);
        break;
      case AppUserRole.seminarInstructor:
        context.go(AppRoutes.instructorHome);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          const Positioned(
            top: -50,
            left: -50,
            child: FloatingBlob(gradient: AppColors.heroGradient, size: 200, opacity: 0.12),
          ),
          Positioned(
            bottom: -70,
            right: -60,
            child: const FloatingBlob(
              gradient: AppColors.successGradient,
              size: 240,
              opacity: 0.10,
              reverse: true,
            ).animate().fadeIn(duration: 800.ms),
          ),
          SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    // لوگوی کامل و بدون برش (نشان + هر دو خط متن + تزئینات).
                    child: SizedBox(
                      width: 240,
                      height: 224,
                      child: Image.asset(
                        'assets/logo/app_logo_lockup.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.school_rounded,
                            size: 96,
                            color: Colors.white),
                      ),
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.6, 0.6),
                        end: const Offset(1, 1),
                        duration: 500.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 300.ms)
                      .then()
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1, end: 1.035, duration: 1800.ms, curve: Curves.easeInOut),
                  const SizedBox(height: 20),
                  Text(
                    context.tr('common.appName'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ).animate().fadeIn(delay: 150.ms, duration: 400.ms).slideY(begin: 0.2, end: 0, delay: 150.ms, duration: 400.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push(AppRoutes.welcome),
                      icon: const Icon(Icons.help_outline_rounded, size: 16),
                      label: Text(context.tr('welcome.howToUse'), style: const TextStyle(fontSize: 12)),
                    ),
                  ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
                  Text(
                    context.tr('auth.loginTitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ).animate().fadeIn(delay: 220.ms, duration: 400.ms),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: context.tr('auth.email'),
                              prefixIcon: const Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? context.tr('common.required') : null,
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            decoration: InputDecoration(
                              labelText: context.tr('auth.password'),
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) =>
                                (v == null || v.isEmpty) ? context.tr('common.required') : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: scheme.errorContainer,
                                borderRadius: BorderRadius.circular(AppRadii.sm),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, size: 18, color: scheme.error),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(_error!,
                                        style: TextStyle(color: scheme.error, fontSize: 13)),
                                  ),
                                ],
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 250.ms)
                                .shake(hz: 4, offset: const Offset(6, 0), duration: 400.ms),
                          ],
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  value: _rememberMe,
                                  onChanged: (v) =>
                                      setState(() => _rememberMe = v ?? false),
                                  title: Text(
                                    context.tr('auth.rememberMe'),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                              TextButton(
                                onPressed: () => context.push(AppRoutes.forgotPassword),
                                child: Text(context.tr('auth.forgotPassword')),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          AppPrimaryButton(
                            label: context.tr('auth.loginButton'),
                            loading: _submitting,
                            onPressed: _submit,
                            icon: Icons.arrow_forward_rounded,
                          ),
                        ],
                      ),
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 280.ms, duration: 450.ms)
                      .slideY(begin: 0.15, end: 0, delay: 280.ms, duration: 450.ms, curve: Curves.easeOutCubic),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(context.tr('auth.dontHaveAccount'),
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                      ),
                      Expanded(child: Divider(color: scheme.outlineVariant)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () => context.push(AppRoutes.registerRoleSelect),
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(context.tr('auth.registerButton')),
                  ),
                ],
              ),
            ),
          ),
        ),
          ),
        ],
      ),
    );
  }
}

