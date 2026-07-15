import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/country_phone_field.dart';
import '../../../../core/widgets/date_of_birth_field.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../providers/auth_providers.dart';
import '../widgets/terms_gate.dart';

/// ثبت‌نام دانش‌آموز — طبق بخش ۳.۱ و ۳ب سند (نیازمند Invite Code معتبر).
class RegisterStudentScreen extends ConsumerStatefulWidget {
  const RegisterStudentScreen({super.key});

  @override
  ConsumerState<RegisterStudentScreen> createState() => _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends ConsumerState<RegisterStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _dob = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController(text: '+93');
  final _password = TextEditingController();
  final _inviteCode = TextEditingController();
  int _grade = AppConstants.grades.first;
  String _province = AppConstants.provinces.first;
  bool _submitting = false;
  bool _acceptedTerms = false;
  bool _showTermsError = false;
  String? _error;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _dob.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _inviteCode.dispose();
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
    final ok = await ref.read(authSessionProvider.notifier).registerStudent(
          RegisterStudentParams(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            dateOfBirth: _dob.text.trim(),
            email: _email.text.trim(),
            phone: _phone.text.trim(),
            password: _password.text,
            currentGrade: _grade,
            province: _province,
            inviteCode: _inviteCode.text.trim(),
          ),
        );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (!ok) {
      setState(() => _error = ref.read(authSessionProvider.notifier).lastError);
      return;
    }
    context.go(AppRoutes.studentHome);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('auth.registerStudent'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 76,
                      height: 76,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        gradient: AppColors.heroGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.warm,
                      ),
                      child: const Icon(Icons.face_3_rounded, size: 36, color: Colors.white),
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
                          Row(children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstName,
                                decoration: InputDecoration(labelText: context.tr('auth.firstName')),
                                validator: (v) => (v == null || v.trim().length < 2)
                                    ? context.tr('common.required')
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastName,
                                decoration: InputDecoration(labelText: context.tr('auth.lastName')),
                                validator: (v) => (v == null || v.trim().length < 2)
                                    ? context.tr('common.required')
                                    : null,
                              ),
                            ),
                          ]),
                          const SizedBox(height: 12),
                          DateOfBirthField(controller: _dob),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(labelText: context.tr('auth.email')),
                            validator: (v) =>
                                (v == null || !v.contains('@')) ? context.tr('common.required') : null,
                          ),
                          const SizedBox(height: 12),
                          // شمارهٔ تلفن با انتخاب‌گر پویای کد کشور — به‌جای پیش‌فرض
                          // ثابتِ افغانستان، تا شاگردان از هر کشوری بتوانند ثبت‌نام کنند.
                          CountryPhoneField(
                            controller: _phone,
                            label: context.tr('auth.phone'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            initialValue: _grade,
                            decoration: InputDecoration(labelText: context.tr('auth.currentGrade')),
                            items: AppConstants.grades
                                .map((g) => DropdownMenuItem(value: g, child: Text('$g')))
                                .toList(),
                            onChanged: (v) => setState(() => _grade = v ?? _grade),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _province,
                            decoration: InputDecoration(labelText: context.tr('common.province')),
                            isExpanded: true,
                            items: AppConstants.provinces
                                .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                                .toList(),
                            onChanged: (v) => setState(() => _province = v ?? _province),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: true,
                            decoration: InputDecoration(labelText: context.tr('auth.password')),
                            validator: (v) =>
                                (v == null || v.length < 8) ? context.tr('common.required') : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _inviteCode,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: context.tr('auth.inviteCode'),
                              helperText: context.tr('auth.inviteCodeHint'),
                            ),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty) ? context.tr('common.required') : null,
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
