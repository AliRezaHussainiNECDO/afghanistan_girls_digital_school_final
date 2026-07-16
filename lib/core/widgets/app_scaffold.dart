import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/design_tokens.dart';
import '../../features/auth/domain/entities/app_user.dart';
import 'app_drawer.dart';
import 'language_theme_menu.dart';

/// Scaffold مشترک تمام صفحات داخل اپ (بعد از ورود) — AppBar گرادیانی گرم +
/// Drawer وابسته به نقش + دکمهٔ زبان/تم، طبق سیستم طراحی جدید.
class AppScaffold extends ConsumerWidget {
  final String title;
  final AppUserRole role;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final bool centerTitle;

  const AppScaffold({
    super.key,
    required this.title,
    required this.role,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.centerTitle = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // طبق درخواست صریح کاربر: در همهٔ صفحات همهٔ داشبوردها (شاگرد/والد/مدیر)
    // یک دکمهٔ بازگشت زیبا و یکسان لازم است. قبلاً این AppBar به تشخیص
    // پیش‌فرض Flutter (`automaticallyImplyLeading`) وابسته بود که با ترکیب
    // `context.go`/`context.push` در go_router همیشه قابل‌اعتماد نیست —
    // بعضی صفحات با اینکه واقعاً قابل بازگشت بودند، دکمه‌ای نشان نمی‌دادند.
    // حالا صراحتاً بر اساس `Navigator.canPop` تصمیم می‌گیریم و یک دکمهٔ
    // دایره‌ای مدرن با پس‌زمینهٔ نیمه‌شفاف طراحی می‌کنیم؛ وقتی صفحه‌ای برای
    // بازگشت ندارد (صفحات اصلی/ریشهٔ هر داشبورد)، به‌جای آن همان آیکن منوی
    // کشویی (Drawer) پیش‌فرض باقی می‌ماند — رفتار درست و بدون تغییر.
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(AppRadii.lg)),
          child: Container(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: AppBar(
              title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              centerTitle: centerTitle,
              iconTheme: const IconThemeData(color: Colors.white),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: canPop ? const _ModernBackButton() : null,
              actions: [
                ...?actions,
                const LanguageThemeMenu(),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      drawer: AppDrawer(role: role),
      backgroundColor: scheme.surface,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// دکمهٔ بازگشت مدرن و پویا — دایرهٔ نیمه‌شفاف با پیکان گرد و یک لرزش ظریف
/// هنگام لمس، هماهنگ با گرادیان گرم AppBar در همهٔ صفحات برنامه.
class _ModernBackButton extends StatefulWidget {
  const _ModernBackButton();

  @override
  State<_ModernBackButton> createState() => _ModernBackButtonState();
}

class _ModernBackButtonState extends State<_ModernBackButton> with SingleTickerProviderStateMixin {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    // جهت پیکان باید با جهت متن هماهنگ باشد: در حالت راست‌به‌چپ (دری/پشتو)
    // «بازگشت» یعنی پیکان به‌سمت راست، در چپ‌به‌راست (مثلاً انگلیسی) برعکس —
    // چون این اپ سوییچ زبان دارد (`LanguageThemeMenu`)، جهت هرگز فرض ثابت
    // گرفته نمی‌شود و از `Directionality` واقعیِ لحظه خوانده می‌شود.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.white.withValues(alpha: 0.18),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTapDown: (_) => setState(() => _scale = 0.88),
            onTapCancel: () => setState(() => _scale = 1.0),
            onTap: () {
              setState(() => _scale = 1.0);
              Navigator.of(context).maybePop();
            },
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(
                isRtl ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
