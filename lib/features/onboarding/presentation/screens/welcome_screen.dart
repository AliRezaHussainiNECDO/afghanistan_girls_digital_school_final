import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/permissions/permissions_sheet.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/floating_blob.dart';
import '../providers/onboarding_providers.dart';

class _Slide {
  final IconData icon;
  final Gradient gradient;
  final String titleKey;
  final String bodyKey;
  const _Slide(this.icon, this.gradient, this.titleKey, this.bodyKey);
}

const _slides = [
  _Slide(Icons.auto_stories_rounded, AppColors.sunriseGradient, 'welcome.slide1Title', 'welcome.slide1Body'),
  _Slide(Icons.smart_toy_rounded, AppColors.heroGradient, 'welcome.slide2Title', 'welcome.slide2Body'),
  _Slide(Icons.map_rounded, AppColors.successGradient, 'welcome.slide3Title', 'welcome.slide3Body'),
  _Slide(Icons.person_add_alt_1_rounded, AppColors.heroGradientWarm, 'welcome.slide4Title', 'welcome.slide4Body'),
];

/// صفحهٔ خوش‌آمدید/معرفی برنامه — طبق درخواست کاربر: «صفحه خوش‌آمدید و
/// معرفی برنامه و چگونگی استفاده و ساخت حساب». یک‌بار برای کاربران جدید
/// نمایش داده می‌شود و همیشه از صفحهٔ ورود در دسترس است.
///
/// نسخهٔ به‌روزشده: پس‌زمینهٔ محو شناور، آیکن با تنفس/چرخش ملایم، و
/// ورود پلکانی متن‌ها — تا حس یک اپ سرگرم‌کننده و دلگرم‌کننده برای
/// دختران بدهد.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _controller = PageController();
  int _index = 0;

  Future<void> _finish() async {
    // درخواست دسترسی‌های دستگاه در پایان معرفی (فقط موبایل، یک‌بار).
    await PermissionsSheet.maybePrompt(context);
    if (!mounted) return;
    ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLast = _index == _slides.length - 1;
    final currentSlide = _slides[_index];

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        children: [
          // --- حباب‌های گرادیانی محو در پس‌زمینه، به‌آرامی شناور ---
          Positioned(
            top: -60,
            right: -40,
            child: FloatingBlob(gradient: currentSlide.gradient, size: 220, opacity: 0.16),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: FloatingBlob(gradient: currentSlide.gradient, size: 260, opacity: 0.12, reverse: true),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(context.tr('welcome.skip')),
                    ),
                  ),
                ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _slides.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (context, i) {
                      final slide = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: slide.gradient,
                                shape: BoxShape.circle,
                                boxShadow: AppShadows.warm,
                              ),
                              child: Icon(slide.icon, size: 64, color: Colors.white),
                            )
                                .animate()
                                .scale(
                                  begin: const Offset(0.4, 0.4),
                                  end: const Offset(1, 1),
                                  duration: 550.ms,
                                  curve: Curves.elasticOut,
                                )
                                .fadeIn(duration: 300.ms)
                                .then()
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .moveY(begin: 0, end: -10, duration: 1600.ms, curve: Curves.easeInOut),
                            const SizedBox(height: 36),
                            Text(
                              context.tr(slide.titleKey),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            )
                                .animate()
                                .fadeIn(delay: 200.ms, duration: 400.ms)
                                .slideY(begin: 0.25, end: 0, delay: 200.ms, duration: 400.ms, curve: Curves.easeOutCubic),
                            const SizedBox(height: 14),
                            Text(
                              context.tr(slide.bodyKey),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
                            )
                                .animate()
                                .fadeIn(delay: 320.ms, duration: 400.ms)
                                .slideY(begin: 0.25, end: 0, delay: 320.ms, duration: 400.ms, curve: Curves.easeOutCubic),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (i) {
                    final active = i == _index;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: active ? currentSlide.gradient : null,
                        color: active ? null : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    );
                  }),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: AppPrimaryButton(
                    label: isLast ? context.tr('welcome.getStarted') : context.tr('common.next'),
                    gradient: currentSlide.gradient,
                    icon: isLast ? Icons.rocket_launch_rounded : Icons.arrow_forward_rounded,
                    onPressed: () {
                      if (isLast) {
                        _finish();
                      } else {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 380),
                          curve: Curves.easeOutCubic,
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
