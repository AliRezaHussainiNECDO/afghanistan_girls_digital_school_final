import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// تم روشن/تاریک اپ — سیستم طراحی گرم و مدرن (نارنجی/زرد + سبز)، جایگزین
/// تم کلاسیک سبز پیش‌فرض Material. فونت Vazirmatn برای خوانایی بهتر فارسی/دری.
class AppTheme {
  AppTheme._();

  /// فونت ایموجی رنگی Noto به‌عنوان fallback — بدون این، ایموجی‌های داخل
  /// متن‌ها (🌸 ✅ …) در وب باعث هشدار «Could not find a set of Noto fonts»
  /// می‌شوند چون Vazirmatn ایموجی ندارد.
  static final List<String> _emojiFallback = [
    GoogleFonts.notoColorEmoji().fontFamily!,
  ];

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = GoogleFonts.vazirmatnTextTheme()
        .apply(fontFamilyFallback: _emojiFallback);
    return base
        .copyWith(
          displayLarge: base.displayLarge?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w800),
          headlineLarge: base.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
          headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          headlineSmall: base.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          titleLarge: base.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          bodyLarge: base.bodyLarge?.copyWith(fontWeight: FontWeight.w500, height: 1.5),
          bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w500, height: 1.5),
          labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
  }

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.orange500,
    onPrimary: Colors.white,
    primaryContainer: AppColors.orange100,
    onPrimaryContainer: AppColors.orange700,
    secondary: AppColors.green600,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.green100,
    onSecondaryContainer: AppColors.green700,
    tertiary: AppColors.gold600,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.gold300,
    onTertiaryContainer: AppColors.ink900,
    error: AppColors.danger,
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD9),
    onErrorContainer: Color(0xFF6E0009),
    surface: AppColors.cream,
    onSurface: AppColors.ink900,
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: AppColors.sand50,
    surfaceContainer: AppColors.sand100,
    surfaceContainerHigh: Color(0xFFEFE3D0),
    surfaceContainerHighest: Color(0xFFEAE0CD),
    onSurfaceVariant: AppColors.ink700,
    outline: AppColors.ink300,
    outlineVariant: Color(0xFFE4D8C6),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: AppColors.ink900,
    onInverseSurface: AppColors.cream,
    inversePrimary: AppColors.orange200,
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColors.orange400,
    onPrimary: Color(0xFF4A1D00),
    primaryContainer: AppColors.orange700,
    onPrimaryContainer: AppColors.orange100,
    secondary: AppColors.green300,
    onSecondary: Color(0xFF063A1C),
    secondaryContainer: AppColors.green700,
    onSecondaryContainer: AppColors.green100,
    tertiary: AppColors.gold500,
    onTertiary: Color(0xFF3A2900),
    tertiaryContainer: AppColors.gold600,
    onTertiaryContainer: Colors.white,
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD9),
    surface: AppColors.darkSurface,
    onSurface: Color(0xFFF3E9DC),
    surfaceContainerLowest: Color(0xFF15100C),
    surfaceContainerLow: Color(0xFF241D15),
    surfaceContainer: AppColors.darkSurfaceHigh,
    surfaceContainerHigh: Color(0xFF352B1F),
    surfaceContainerHighest: Color(0xFF403425),
    onSurfaceVariant: Color(0xFFDCCBB6),
    outline: Color(0xFF8A7D6B),
    outlineVariant: Color(0xFF4A3F31),
    shadow: Colors.black,
    scrim: Colors.black,
    inverseSurface: Color(0xFFF3E9DC),
    onInverseSurface: AppColors.ink900,
    inversePrimary: AppColors.orange600,
  );

  static ThemeData get light => _build(_lightScheme);
  static ThemeData get dark => _build(_darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    final textTheme = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        systemOverlayStyle: null,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.lg),
          side: BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainer,
        selectedColor: scheme.primaryContainer,
        labelStyle: textTheme.labelLarge?.copyWith(color: scheme.onSurface, fontSize: 13),
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: scheme.onPrimaryContainer),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
        side: BorderSide.none,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
          elevation: 0,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          side: BorderSide(color: scheme.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          highlightColor: scheme.primary.withValues(alpha: 0.1),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        labelStyle: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),

      dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(AppRadii.lg)),
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        actionTextColor: scheme.inversePrimary,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg)),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: textTheme.labelLarge,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.surfaceContainerHigh,
        ),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        circularTrackColor: scheme.primaryContainer.withValues(alpha: isDark ? 0.3 : 0.5),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        indicatorColor: scheme.primaryContainer,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      badgeTheme: BadgeThemeData(backgroundColor: scheme.error, textColor: scheme.onError),

      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(scheme.outline.withValues(alpha: 0.5)),
      ),
    );
  }
}
