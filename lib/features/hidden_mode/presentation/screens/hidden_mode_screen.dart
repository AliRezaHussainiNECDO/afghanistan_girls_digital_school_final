import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../providers/hidden_mode_providers.dart';

enum _SetupStep { intro, choosePin, confirmPin, success }

/// صفحهٔ «حالت پنهان» در پروفایل — طبق درخواست صریح کاربر: پویا، مدرن و
/// زیبا، کاملاً به زبان دری (و سه زبان دیگر پلتفرم). دو حالت دارد:
/// • هنوز راه‌اندازی نشده → ویزاردِ معرفی + ساختِ PIN.
/// • از قبل فعال است → کارتِ وضعیت + تغییر PIN / خاموش‌کردن.
class HiddenModeScreen extends ConsumerStatefulWidget {
  const HiddenModeScreen({super.key});

  @override
  ConsumerState<HiddenModeScreen> createState() => _HiddenModeScreenState();
}

class _HiddenModeScreenState extends ConsumerState<HiddenModeScreen> {
  _SetupStep _step = _SetupStep.intro;
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String _firstPin = '';
  String? _error;
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  void _goToChoosePin() {
    setState(() {
      _step = _SetupStep.choosePin;
      _error = null;
      _pinController.clear();
    });
  }

  void _submitFirstPin() {
    final pin = _pinController.text.trim();
    if (pin.length < 4 || pin.length > 8) {
      setState(() => _error = context.tr('hiddenMode.pinTooShort'));
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(pin)) {
      setState(() => _error = context.tr('hiddenMode.pinMustBeDigits'));
      return;
    }
    HapticFeedback.lightImpact();
    setState(() {
      _firstPin = pin;
      _error = null;
      _step = _SetupStep.confirmPin;
      _confirmController.clear();
    });
  }

  Future<void> _submitConfirmPin() async {
    final confirm = _confirmController.text.trim();
    if (confirm != _firstPin) {
      setState(() => _error = context.tr('hiddenMode.pinMismatch'));
      return;
    }
    setState(() => _busy = true);
    await ref.read(hiddenModeProvider.notifier).setup(confirm);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _busy = false;
      _error = null;
      _step = _SetupStep.success;
    });
  }

  Future<void> _showChangePinDialog() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final scheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('hiddenMode.changePin')),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('hiddenMode.currentPinField')),
                validator: (v) => (v == null || v.isEmpty) ? context.tr('common.required') : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: newCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr('hiddenMode.newPinField')),
                validator: (v) {
                  if (v == null || v.length < 4 || v.length > 8) {
                    return context.tr('hiddenMode.pinTooShort');
                  }
                  if (!RegExp(r'^\d+$').hasMatch(v)) return context.tr('hiddenMode.pinMustBeDigits');
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('common.cancel'))),
          FilledButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final ok = await ref
                  .read(hiddenModeProvider.notifier)
                  .changePin(currentCtrl.text.trim(), newCtrl.text.trim());
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(ok ? context.tr('hiddenMode.pinChanged') : context.tr('hiddenMode.wrongPin')),
                  backgroundColor: ok ? scheme.primary : scheme.error,
                ),
              );
            },
            child: Text(context.tr('common.save')),
          ),
        ],
      ),
    );
  }

  Future<void> _showTurnOffDialog() async {
    final pinCtrl = TextEditingController();
    final scheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.tr('hiddenMode.turnOffConfirmTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('hiddenMode.turnOffConfirmBody')),
            const SizedBox(height: 16),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: context.tr('hiddenMode.currentPinField')),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(context.tr('common.cancel'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () async {
              final notifier = ref.read(hiddenModeProvider.notifier);
              // بازکردنِ رمز به‌عنوانِ تأیید هویت پیش از خاموش‌کردن — رمزِ
              // فعلی همچنان معتبر می‌ماند، فقط برای اطمینان بررسی می‌شود.
              final valid = await notifier.reveal(pinCtrl.text.trim());
              if (valid) {
                await notifier.disable();
              }
              if (!dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(valid ? context.tr('hiddenMode.disabledNotice') : context.tr('hiddenMode.wrongPin')),
                  backgroundColor: valid ? scheme.primary : scheme.error,
                ),
              );
            },
            child: Text(context.tr('hiddenMode.turnOff')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hidden = ref.watch(hiddenModeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('hiddenMode.title'))),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: !_isAndroid
              ? _buildUnsupported(scheme)
              : hidden.loading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 80),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : hidden.enabled
                      ? _buildManageView(scheme)
                      : _buildSetupWizard(scheme),
        ),
      ),
    );
  }

  Widget _buildUnsupported(ColorScheme scheme) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.phone_iphone_rounded, size: 72, color: scheme.onSurfaceVariant),
        const SizedBox(height: 20),
        Text(
          context.tr('hiddenMode.notAvailableAndroidOnly'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ],
    );
  }

  // ── حالتِ «از قبل فعال است» ────────────────────────────────────────────
  Widget _buildManageView(ColorScheme scheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.successGradient,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: AppShadows.green,
          ),
          child: Column(
            children: [
              const Icon(Icons.shield_rounded, color: Colors.white, size: 48)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 1, end: 1.08, duration: 1400.ms, curve: Curves.easeInOut),
              const SizedBox(height: 12),
              Text(
                context.tr('hiddenMode.statusActiveTitle'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('hiddenMode.statusActiveBody'),
                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.6),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.08, end: 0, duration: 380.ms),
        const SizedBox(height: 20),
        _actionTile(
          icon: Icons.password_rounded,
          color: scheme.primary,
          title: context.tr('hiddenMode.changePin'),
          onTap: _showChangePinDialog,
        ).animate().fadeIn(delay: 100.ms, duration: 300.ms),
        const SizedBox(height: 12),
        _actionTile(
          icon: Icons.visibility_off_rounded,
          color: scheme.error,
          title: context.tr('hiddenMode.turnOff'),
          onTap: _showTurnOffDialog,
        ).animate().fadeIn(delay: 160.ms, duration: 300.ms),
      ],
    );
  }

  Widget _actionTile({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_left_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ── ویزاردِ راه‌اندازی ──────────────────────────────────────────────────
  Widget _buildSetupWizard(ColorScheme scheme) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
          child: child,
        ),
      ),
      child: switch (_step) {
        _SetupStep.intro => _buildIntro(scheme, key: const ValueKey('intro')),
        _SetupStep.choosePin => _buildPinStep(
            key: const ValueKey('choose'),
            title: context.tr('hiddenMode.enterPinTitle'),
            hint: context.tr('hiddenMode.enterPinHint'),
            controller: _pinController,
            onSubmit: _submitFirstPin,
            buttonLabel: context.tr('common.next'),
          ),
        _SetupStep.confirmPin => _buildPinStep(
            key: const ValueKey('confirm'),
            title: context.tr('hiddenMode.confirmPinField'),
            hint: context.tr('hiddenMode.confirmPinHint'),
            controller: _confirmController,
            onSubmit: _submitConfirmPin,
            buttonLabel: context.tr('common.confirm'),
            busy: _busy,
          ),
        _SetupStep.success => _buildSuccess(scheme, key: const ValueKey('success')),
      },
    );
  }

  Widget _buildIntro(ColorScheme scheme, {required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: AppColors.sunriseGradient,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: AppShadows.warm,
          ),
          child: Column(
            children: [
              const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 56)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(begin: 0.94, end: 1.06, duration: 1600.ms, curve: Curves.easeInOut)
                  .then()
                  .shimmer(duration: 1800.ms, color: Colors.white24),
              const SizedBox(height: 16),
              Text(
                context.tr('hiddenMode.introTitle'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
              ),
              const SizedBox(height: 10),
              Text(
                context.tr('hiddenMode.introBody'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.7),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.08, end: 0, duration: 380.ms),
        const SizedBox(height: 18),
        _bulletCard(Icons.volume_down_rounded, context.tr('hiddenMode.introBullet1'), scheme.primary, 60),
        const SizedBox(height: 10),
        _bulletCard(Icons.calculate_rounded, context.tr('hiddenMode.introBullet2'), scheme.secondary, 120),
        const SizedBox(height: 10),
        _bulletCard(Icons.android_rounded, context.tr('hiddenMode.introBullet3'), scheme.tertiary, 180),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.errorContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_rounded, color: scheme.error, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.tr('hiddenMode.introWarning'),
                  style: TextStyle(fontSize: 12.5, color: scheme.onErrorContainer, height: 1.6),
                ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
        const SizedBox(height: 22),
        FilledButton(
          onPressed: _goToChoosePin,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: Text(context.tr('hiddenMode.startSetup'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ).animate().fadeIn(delay: 260.ms, duration: 300.ms),
      ],
    );
  }

  Widget _bulletCard(IconData icon, String text, Color color, int delayMs) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.md),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13, height: 1.6))),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delayMs.ms, duration: 300.ms).slideX(begin: 0.04, end: 0, duration: 300.ms);
  }

  Widget _buildPinStep({
    required Key key,
    required String title,
    required String hint,
    required TextEditingController controller,
    required VoidCallback onSubmit,
    required String buttonLabel,
    bool busy = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(gradient: AppColors.heroGradientWarm, shape: BoxShape.circle),
            child: const Icon(Icons.lock_rounded, color: Colors.white, size: 38),
          ).animate().scale(duration: 320.ms, curve: Curves.easeOutBack),
        ),
        const SizedBox(height: 20),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        const SizedBox(height: 6),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: controller,
          obscureText: _obscure,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 8,
          style: const TextStyle(fontSize: 26, letterSpacing: 10, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: scheme.surfaceContainerLowest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadii.lg),
              borderSide: BorderSide(color: scheme.outlineVariant),
            ),
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: scheme.error, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
        ],
        const SizedBox(height: 22),
        FilledButton(
          onPressed: busy ? null : onSubmit,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: busy
              ? const SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
              : Text(buttonLabel, style: const TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _buildSuccess(ColorScheme scheme, {required Key key}) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(gradient: AppColors.successGradient, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
          ).animate().scale(duration: 420.ms, curve: Curves.elasticOut),
        ),
        const SizedBox(height: 20),
        Text(
          context.tr('hiddenMode.setupSuccessTitle'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
        const SizedBox(height: 10),
        Text(
          context.tr('hiddenMode.setupSuccessBody'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.8, color: scheme.onSurfaceVariant),
        ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: Text(context.tr('hiddenMode.done'), style: const TextStyle(fontWeight: FontWeight.w700)),
        ).animate().fadeIn(delay: 220.ms, duration: 300.ms),
      ],
    );
  }
}
