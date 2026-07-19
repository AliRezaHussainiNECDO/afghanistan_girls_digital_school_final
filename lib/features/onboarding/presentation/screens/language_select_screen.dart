import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/widgets/floating_blob.dart';
import '../providers/language_select_providers.dart';

class _LanguageOption {
  final Locale locale;
  final String nativeName;
  final String subtitle;
  final bool rtl;
  const _LanguageOption({
    required this.locale,
    required this.nativeName,
    required this.subtitle,
    required this.rtl,
  });
}

const _options = [
  _LanguageOption(locale: Locale('fa'), nativeName: 'دری', subtitle: 'ادامه به زبان دری', rtl: true),
  _LanguageOption(locale: Locale('ps'), nativeName: 'پښتو', subtitle: 'په پښتو ژبه دوام ورکړئ', rtl: true),
  _LanguageOption(locale: Locale('en'), nativeName: 'English', subtitle: 'Continue in English', rtl: false),
  _LanguageOption(locale: Locale('fr'), nativeName: 'Français', subtitle: 'Continuer en français', rtl: false),
];

/// صفحهٔ انتخاب زبان — طبق درخواست صریح کاربر: «در اولین بار باز کردن
/// برنامه بعد از نصب» باید پیش از هر صفحهٔ دیگری (حتی پیش از خوش‌آمدید)
/// از کاربر خواسته شود زبان برنامه را از میان چهار زبان دری/پښتو/English/
/// Français انتخاب کند؛ پس از انتخاب، *تمام* برنامه بلافاصله به همان زبان
/// تغییر می‌کند و این پرچم دیگر هرگز دوباره نشان داده نمی‌شود (مگر از طریق
/// تنظیمات کاربر زبان را عوض کند که آن یک مسیر جداست).
///
/// چون در این لحظه هنوز نمی‌دانیم کاربر کدام زبان را می‌فهمد، متن راهنما
/// همزمان به هر چهار زبان نوشته شده — نه فقط زبان پیش‌فرض دستگاه.
class LanguageSelectScreen extends ConsumerStatefulWidget {
  const LanguageSelectScreen({super.key});

  @override
  ConsumerState<LanguageSelectScreen> createState() => _LanguageSelectScreenState();
}

class _LanguageSelectScreenState extends ConsumerState<LanguageSelectScreen> {
  Locale? _picking;

  Future<void> _choose(_LanguageOption option) async {
    if (_picking != null) return;
    setState(() => _picking = option.locale);
    await ref.read(localeProvider.notifier).setLocale(option.locale);
    await ref.read(languageChosenProvider.notifier).markChosen();
    if (!mounted) return;
    // منطق Redirect در روتر خودش تصمیم می‌گیرد بعد از این به کجا برود
    // (صفحهٔ خوش‌آمدید برای کاربران کاملاً تازه، یا مستقیم صفحهٔ ورود).
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          const Positioned(
            top: -60,
            right: -40,
            child: FloatingBlob(gradient: AppColors.sunriseGradient, size: 220, opacity: 0.16),
          ),
          const Positioned(
            bottom: -80,
            left: -60,
            child: FloatingBlob(gradient: AppColors.heroGradient, size: 260, opacity: 0.12, reverse: true),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      gradient: AppColors.sunriseGradient,
                      shape: BoxShape.circle,
                      boxShadow: AppShadows.warm,
                    ),
                    child: const Icon(Icons.language_rounded, size: 42, color: Colors.white),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1, 1),
                        duration: 450.ms,
                        curve: Curves.easeOutBack,
                      )
                      .fadeIn(duration: 300.ms),
                  const SizedBox(height: 24),
                  // ── راهنما هم‌زمان به هر چهار زبان — چون هنوز زبان کاربر
                  // معلوم نیست. ──
                  Text(
                    'زبان برنامه را انتخاب کنید',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ).animate().fadeIn(delay: 120.ms, duration: 350.ms),
                  const SizedBox(height: 6),
                  Text(
                    'د اپلیکیشن ژبه غوره کړئ  ·  Choose your language  ·  Choisissez votre langue',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5, height: 1.7),
                  ).animate().fadeIn(delay: 200.ms, duration: 350.ms),
                  const SizedBox(height: 36),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _options.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (context, i) {
                        final option = _options[i];
                        final busy = _picking == option.locale;
                        return _LanguageCard(
                          option: option,
                          busy: busy,
                          disabled: _picking != null && !busy,
                          onTap: () => _choose(option),
                        )
                            .animate()
                            .fadeIn(delay: (280 + i * 70).ms, duration: 320.ms)
                            .slideY(begin: 0.18, end: 0, delay: (280 + i * 70).ms, duration: 320.ms, curve: Curves.easeOutCubic);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageCard extends StatelessWidget {
  final _LanguageOption option;
  final bool busy;
  final bool disabled;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.option,
    required this.busy,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Material(
        color: scheme.surfaceContainerLowest,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: disabled ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              textDirection: option.rtl ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.translate_rounded, color: scheme.primary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.nativeName,
                        textDirection: option.rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle,
                        textDirection: option.rtl ? TextDirection.rtl : TextDirection.ltr,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
