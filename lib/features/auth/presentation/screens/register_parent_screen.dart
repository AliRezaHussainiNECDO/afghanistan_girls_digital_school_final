import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../providers/auth_providers.dart';
import '../widgets/terms_gate.dart';

/// ثبت‌نام والدین — طبق بخش ۳.۶ سند. پس از ثبت‌نام، والد باید حداقل یک
/// پیوند فرزند را با کد دعوت تکمیل کند (بخش ۲.۴/۱۳ب) — در پارنت دشبورد.
class RegisterParentScreen extends ConsumerStatefulWidget {
  const RegisterParentScreen({super.key});

  @override
  ConsumerState<RegisterParentScreen> createState() => _RegisterParentScreenState();
}

class _RegisterParentScreenState extends ConsumerState<RegisterParentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+93');
  final _password = TextEditingController();
  bool _submitting = false;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _showTermsError = true);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await ref.read(authSessionProvider.notifier).registerParent(
          RegisterParentParams(
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
          ),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      setState(() => _error = ref.read(authSessionProvider.notifier).lastError);
      return;
    }
    context.go(AppRoutes.parentDashboard);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('auth.registerParent'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: AppColors.successGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.green,
                      ),
                      child: const Icon(Icons.family_restroom_rounded, size: 36, color: Colors.white),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadii.xl),
                      boxShadow: AppShadows.soft,
                    ),
                    child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _fullName,
                      decoration: InputDecoration(labelText: context.tr('auth.firstName')),
                      validator: (v) =>
                          (v == null || v.trim().length < 2) ? context.tr('common.required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(labelText: context.tr('auth.email')),
                      validator: (v) =>
                          (v == null || !v.contains('@')) ? context.tr('common.required') : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(labelText: context.tr('auth.phone')),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      obscureText: true,
                      decoration: InputDecoration(labelText: context.tr('auth.password')),
                      validator: (v) =>
                          (v == null || v.length < 8) ? context.tr('common.required') : null,
                    ),
                    const SizedBox(height: 8),
                    TermsConsentField(
                      accepted: _acceptedTerms,
                      showError: _showTermsError,
                      onChanged: (v) => setState(() {
                        _acceptedTerms = v;
                        if (v) _showTermsError = false;
                      }),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    const SizedBox(height: 20),
                    AppPrimaryButton(
                      label: context.tr('auth.registerButton'),
                      loading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
