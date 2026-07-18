import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../localization/app_localizations.dart';
import '../localization/locale_provider.dart';
import '../../app/theme/theme_provider.dart';

/// دکمهٔ سوئیچ زبان/تم در AppBar — طبق نیازمندی «دارک‌مود + ۳ زبان کار می‌کند»
/// (معیار پذیرش فاز ۱، بخش ۲۵.۳ سند). ظاهر: آیکن داخل حباب دایره‌ای نرم.
class LanguageThemeMenu extends ConsumerWidget {
  const LanguageThemeMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Bubble(
          scheme: scheme,
          child: PopupMenuButton<Locale>(
            icon: Icon(Icons.language_rounded, color: scheme.onSurface, size: 20),
            tooltip: context.tr('common.language'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (locale) => ref.read(localeProvider.notifier).setLocale(locale),
            itemBuilder: (context) => const [
              PopupMenuItem(value: Locale('fa'), child: Text('دری')),
              PopupMenuItem(value: Locale('ps'), child: Text('پښتو')),
              PopupMenuItem(value: Locale('en'), child: Text('English')),
              PopupMenuItem(value: Locale('fr'), child: Text('Français')),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Bubble(
          scheme: scheme,
          child: PopupMenuButton<ThemeMode>(
            icon: Icon(Icons.brightness_6_rounded, color: scheme.onSurface, size: 20),
            tooltip: context.tr('common.theme'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (mode) => ref.read(themeModeProvider.notifier).setThemeMode(mode),
            itemBuilder: (context) => [
              PopupMenuItem(value: ThemeMode.light, child: Text(context.tr('common.lightMode'))),
              PopupMenuItem(value: ThemeMode.dark, child: Text(context.tr('common.darkMode'))),
              PopupMenuItem(value: ThemeMode.system, child: Text(context.tr('common.systemMode'))),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final Widget child;
  final ColorScheme scheme;
  const _Bubble({required this.child, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: scheme.surfaceContainer, shape: BoxShape.circle),
      child: child,
    );
  }
}
