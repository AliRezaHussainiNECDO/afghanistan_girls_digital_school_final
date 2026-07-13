import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';
import '../core/localization/locale_provider.dart';
import '../core/widgets/celebration_overlay.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';

/// ریشهٔ اپلیکیشن — طبق بخش ۲۴.۴ سند (`app/app.dart`): اتصال تم، زبان و روتر.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'مکتب دیجیتال دختران افغانستان',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) {
        final isRtl = locale.languageCode == 'fa' || locale.languageCode == 'ps';
        return Directionality(
          textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
          child: CelebrationOverlay(child: child ?? const SizedBox.shrink()),
        );
      },
    );
  }
}
