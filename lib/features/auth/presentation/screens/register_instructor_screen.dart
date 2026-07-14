import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/country_phone_field.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../providers/auth_providers.dart';
import '../widgets/terms_gate.dart';

/// ثبت‌نام استاد سمینار.
///
/// منطق (بخش ۲.۲ سند: «افزودن استاد» در انحصار Super Admin):
/// ۱. مدیر از CMS ← «کدهای استادان» یک کد یک‌بارمصرف برای استاد می‌سازد و
///    به او می‌دهد.
/// ۲. استاد در این صفحه معلومات ضروری‌اش (نام، ایمیل، تلفن، تخصص، سابقه)
///    را وارد و با همان کد حسابش را فعال می‌کند.
/// ۳. پس از موفقیت، مستقیم به پنل استاد (سمینارها) هدایت می‌شود.
class RegisterInstructorScreen extends ConsumerStatefulWidget {
  const RegisterInstructorScreen({super.key});

  @override
  ConsumerState<RegisterInstructorScreen> createState() => _RegisterInstructorScreenState();
}

class _RegisterInstructorScreenState extends ConsumerState<RegisterInstructorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+93');
  final _specialty = TextEditingController();
  final _bio = TextEditingController();
  final _inviteCode = TextEditingController();
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
    _specialty.dispose();
    _bio.dispose();
    _inviteCode.dispose();
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
    final ok = await ref.read(authSessionProvider.notifier).registerInstructor(
          RegisterInstructorParams(
            fullName: _fullName.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
            specialty: _specialty.text.trim(),
            bio: _bio.text.trim(),
            inviteCode: _inviteCode.text.trim(),
          ),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      setState(() => _error = ref.read(authSessionProvider.notifier).lastError);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('خوش آمدید ${_fullName.text.trim()}! حساب استاد شما فعال شد')),
    );
    context.go(AppRoutes.instructorHome);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('ثبت‌نام استاد سمینار')),
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
                        gradient: AppColors.heroGradientWarm,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.soft,
                      ),
                      child: const Icon(Icons.co_present_rounded, size: 36, color: Colors.white),
                    ),
                  ),
                  // ── راهنمای کد دعوت ──
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: scheme.tertiary.withValues(alpha: 0.35)),
                    ),
                    child: Row(children: [
                      Icon(Icons.info_outline_rounded, size: 20, color: scheme.tertiary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ثبت‌نام استاد فقط با کد دعوتی ممکن است که مدیریت مکتب برای شما ساخته است. اگر کد ندارید، با مدیریت تماس بگیرید.',
                          style: TextStyle(fontSize: 12, height: 1.7, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ]),
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
                          // ── کد دعوت (کلید فعال‌سازی) ──
                          TextFormField(
                            controller: _inviteCode,
                            textDirection: TextDirection.ltr,
                            decoration: const InputDecoration(
                              labelText: 'کد دعوت استاد',
                              hintText: 'TCH-XXXXXX',
                              prefixIcon: Icon(Icons.vpn_key_rounded),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 6) ? 'کد دعوت الزامی است' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _fullName,
                            decoration: const InputDecoration(
                              labelText: 'نام کامل',
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 3) ? context.tr('common.required') : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: context.tr('auth.email'),
                              prefixIcon: const Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? context.tr('common.required') : null,
                          ),
                          const SizedBox(height: 12),
                          // شمارهٔ تلفن با انتخاب‌گر پویای کد کشور — به‌جای پیش‌فرض
                          // ثابتِ افغانستان، تا استادان از هر کشوری بتوانند ثبت‌نام کنند.
                          CountryPhoneField(
                            controller: _phone,
                            label: context.tr('auth.phone'),
                          ),
                          const SizedBox(height: 12),
                          // ── معلومات ضروری تدریس ──
                          TextFormField(
                            controller: _specialty,
                            decoration: const InputDecoration(
                              labelText: 'تخصص / رشتهٔ تدریس',
                              hintText: 'مثلاً: مهارت‌های زندگی، کمپیوتر، ریاضی',
                              prefixIcon: Icon(Icons.school_rounded),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().length < 2) ? 'تخصص الزامی است' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _bio,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              labelText: 'سابقهٔ تدریس / معرفی کوتاه',
                              hintText: 'چند سال تجربه دارید و چه سمینارهایی برگزار کرده‌اید؟',
                              prefixIcon: Icon(Icons.history_edu_rounded),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: context.tr('auth.password'),
                              prefixIcon: const Icon(Icons.lock_rounded),
                            ),
                            validator: (v) =>
                                (v == null || v.length < 8) ? 'رمز حداقل ۸ کاراکتر باشد' : null,
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
                            Text(_error!, style: TextStyle(color: scheme.error)),
                          ],
                          const SizedBox(height: 20),
                          AppPrimaryButton(
                            label: 'فعال‌سازی حساب استاد',
                            loading: _submitting,
                            gradient: AppColors.heroGradientWarm,
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
