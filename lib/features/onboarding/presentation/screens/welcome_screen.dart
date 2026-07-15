import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/permissions/permissions_sheet.dart';
import '../../../../core/widgets/app_primary_button.dart';
import '../../../../core/widgets/celebration_overlay.dart';
import '../../../../core/widgets/floating_blob.dart';
import '../providers/onboarding_providers.dart';

class _Slide {
  final IconData icon;
  final LinearGradient gradient;
  final IconData sparkleIcon;
  final String eyebrowKey;
  final String titleKey;
  final String bodyKey;
  const _Slide({
    required this.icon,
    required this.gradient,
    required this.sparkleIcon,
    required this.eyebrowKey,
    required this.titleKey,
    required this.bodyKey,
  });
}

/// پنج صحنهٔ خوش‌آمدگویی — هرکدام با یک احساس متفاوت: خوش‌آمدگویی گرم،
/// معرفی امکانات یادگیری، انگیزهٔ امتیاز/سطح/گواهی‌نامه (بخش تازه‌اضافه‌شده
/// — چون این‌ها واقعاً در اپ وجود دارند اما قبلاً هرگز در معرفی اولیه تبلیغ
/// نمی‌شدند)، راهنمای شروع، و در نهایت دعوت به ساخت حساب.
const _slides = [
  _Slide(
    icon: Icons.auto_stories_rounded,
    gradient: AppColors.sunriseGradient,
    sparkleIcon: Icons.favorite_rounded,
    eyebrowKey: 'welcome.slide1Eyebrow',
    titleKey: 'welcome.slide1Title',
    bodyKey: 'welcome.slide1Body',
  ),
  _Slide(
    icon: Icons.smart_toy_rounded,
    gradient: AppColors.heroGradient,
    sparkleIcon: Icons.auto_awesome_rounded,
    eyebrowKey: 'welcome.slide2Eyebrow',
    titleKey: 'welcome.slide2Title',
    bodyKey: 'welcome.slide2Body',
  ),
  _Slide(
    icon: Icons.emoji_events_rounded,
    gradient: AppColors.goldCelebrationGradient,
    sparkleIcon: Icons.star_rounded,
    eyebrowKey: 'welcome.slide3Eyebrow',
    titleKey: 'welcome.slide3Title',
    bodyKey: 'welcome.slide3Body',
  ),
  _Slide(
    icon: Icons.map_rounded,
    gradient: AppColors.successGradient,
    sparkleIcon: Icons.route_rounded,
    eyebrowKey: 'welcome.slide4Eyebrow',
    titleKey: 'welcome.slide4Title',
    bodyKey: 'welcome.slide4Body',
  ),
  _Slide(
    icon: Icons.person_add_alt_1_rounded,
    gradient: AppColors.heroGradientWarm,
    sparkleIcon: Icons.rocket_launch_rounded,
    eyebrowKey: 'welcome.slide5Eyebrow',
    titleKey: 'welcome.slide5Title',
    bodyKey: 'welcome.slide5Body',
  ),
];

/// صفحهٔ خوش‌آمدید/معرفی برنامه — طبق درخواست کاربر: «صفحه خوش‌آمدید و
/// معرفی برنامه و چگونگی استفاده و ساخت حساب». یک‌بار برای کاربران جدید
/// نمایش داده می‌شود و همیشه از صفحهٔ ورود در دسترس است.
///
/// نسخهٔ بازطراحی‌شده: پنج صحنهٔ رنگارنگ و پویا (هرکدام با گرادیان و
/// آیکن جداگانه)، برچسب کوچک احساسی بالای هر عنوان، ذره‌های شناور تزئینی
/// پشت‌صحنه، آیکن با تنفس/چرخش ملایم، ورود پلکانی متن‌ها، و یک بارانِ
/// کانفتی کوچک هنگام رسیدن به صحنهٔ آخر — تا حس یک اپ سرگرم‌کننده،
/// مدرن و دلگرم‌کننده برای دختران بدهد و آن‌ها را برای شروع تشویق کند.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _controller = PageController();
  int _index = 0;
  bool _celebrated = false;

  Future<void> _finish() async {
    // درخواست دسترسی‌های دستگاه در پایان معرفی (فقط موبایل، یک‌بار).
    await PermissionsSheet.maybePrompt(context);
    if (!mounted) return;
    ref.read(onboardingSeenProvider.notifier).markSeen();
    if (mounted) context.go(AppRoutes.login);
  }

  void _onPageChanged(int i) {
    setState(() => _index = i);
    if (i == _slides.length - 1 && !_celebrated) {
      _celebrated = true;
      // یک جشن کوچک کانفتی هنگام رسیدن به صحنهٔ آخر — لحظهٔ «آمادهٔ پرواز».
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) CelebrationOverlay.of(context)?.burst();
      });
    }
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
          // --- ذره‌های تزئینی شناور (برق کوچک، ستاره) برای حس زنده و پویا ---
          ..._Sparkle.scattered(currentSlide.sparkleIcon, currentSlide.gradient),
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
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, i) {
                      final slide = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // --- برچسب کوچک احساسی بالای آیکن ---
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                gradient: slide.gradient,
                                borderRadius: BorderRadius.circular(AppRadii.pill),
                              ),
                              child: Text(
                                context.tr(slide.eyebrowKey),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12.5,
                                ),
                              ),
                            )
                                .animate()
                                .fadeIn(duration: 320.ms)
                                .slideY(begin: 0.4, end: 0, duration: 320.ms, curve: Curves.easeOutCubic),
                            const SizedBox(height: 24),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                // --- حلقهٔ نرم پشت آیکن که به‌آرامی نفس می‌کشد ---
                                Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        slide.gradient.colors.first.withValues(alpha: 0.22),
                                        slide.gradient.colors.first.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat(reverse: true))
                                    .scale(
                                      begin: const Offset(0.85, 0.85),
                                      end: const Offset(1.08, 1.08),
                                      duration: 1800.ms,
                                      curve: Curves.easeInOut,
                                    ),
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
                              ],
                            ),
                            const SizedBox(height: 32),
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

/// چند آیکن کوچک تزئینی که در پس‌زمینه محو ظاهر می‌شوند و به‌آرامی
/// می‌چرخند/شناور می‌شوند — فقط برای حس زنده و پویا، بدون مزاحمت برای متن.
class _Sparkle extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final Duration duration;

  const _Sparkle({
    required this.icon,
    required this.color,
    required this.size,
    required this.duration,
  });

  static List<Widget> scattered(IconData icon, LinearGradient gradient) {
    final color = gradient.colors.last;
    return [
      Positioned(
        top: 90,
        left: 24,
        child: _Sparkle(
          icon: icon,
          color: color,
          size: 22,
          duration: const Duration(milliseconds: 2600),
        ),
      ),
      Positioned(
        top: 160,
        right: 32,
        child: _Sparkle(
          icon: icon,
          color: color,
          size: 16,
          duration: const Duration(milliseconds: 3200),
        ),
      ),
      Positioned(
        bottom: 210,
        right: 48,
        child: _Sparkle(
          icon: icon,
          color: color,
          size: 18,
          duration: const Duration(milliseconds: 2900),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: 0.28,
        child: Icon(icon, size: size, color: color),
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .moveY(begin: -6, end: 10, duration: duration, curve: Curves.easeInOut)
          .then()
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .rotate(begin: -0.03, end: 0.03, duration: duration),
    );
  }
}
