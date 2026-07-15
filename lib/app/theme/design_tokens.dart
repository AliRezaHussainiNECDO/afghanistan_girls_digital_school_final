import 'package:flutter/material.dart';

/// توکن‌های طراحی — پالت گرم و دوستانه (نارنجی/زرد + سبز) برای هویت بصری
/// جدید اپ. تمام مقادیر رنگ/شعاع/فاصله/سایه در این فایل مرکزی نگه‌داری
/// می‌شوند تا سراسر اپ یک زبان طراحی واحد داشته باشد.
class AppColors {
  AppColors._();

  // --- برند اصلی: نارنجی گرم (انرژی، یادگیری، خوش‌آمدگویی) ---
  static const Color orange50 = Color(0xFFFFF4EB);
  static const Color orange100 = Color(0xFFFFE3CC);
  static const Color orange200 = Color(0xFFFFC796);
  static const Color orange400 = Color(0xFFFF9A4D);
  static const Color orange500 = Color(0xFFFF8A3D);
  static const Color orange600 = Color(0xFFF06E1F);
  static const Color orange700 = Color(0xFFD4590F);

  // --- برند ثانویه: سبز تازه (رشد، امید، هویت پرچم) ---
  static const Color green50 = Color(0xFFEAF9EF);
  static const Color green100 = Color(0xFFCBF0D8);
  static const Color green300 = Color(0xFF6BCB8E);
  static const Color green500 = Color(0xFF23A15C);
  static const Color green600 = Color(0xFF1B8A4C);
  static const Color green700 = Color(0xFF146B3B);

  // --- تأکیدی: زرد طلایی (ستاره، دستاورد، جشن) ---
  static const Color gold300 = Color(0xFFFFE49A);
  static const Color gold500 = Color(0xFFFFC93C);
  static const Color gold600 = Color(0xFFE8A800);

  // --- خنثی گرم (نه خاکستری سرد کلاسیک) ---
  static const Color cream = Color(0xFFFFFBF5);
  static const Color sand50 = Color(0xFFFBF6EF);
  static const Color sand100 = Color(0xFFF3EADB);
  static const Color ink900 = Color(0xFF2B2016);
  static const Color ink700 = Color(0xFF564A3C);
  static const Color ink500 = Color(0xFF8A7D6B);
  static const Color ink300 = Color(0xFFCBBFAE);

  // --- وضعیت‌ها ---
  static const Color danger = Color(0xFFE5484D);
  static const Color info = Color(0xFF3B82C4);

  // --- سطح تیره ---
  static const Color darkSurface = Color(0xFF1E1812);
  static const Color darkSurfaceHigh = Color(0xFF2A2219);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [orange500, orange600],
  );

  static const LinearGradient heroGradientWarm = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange400, gold500],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green500, green700],
  );

  static const LinearGradient sunriseGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [orange500, gold500, green500],
    stops: [0.0, 0.55, 1.0],
  );

  /// گرادیان طلایی جشن/دستاورد — برای نشان‌ها، سطح‌ها و گواهی‌نامه (بخش
  /// آموزهٔ خوش‌آمدگویی مربوط به امتیاز فعالیت شاگرد).
  static const LinearGradient goldCelebrationGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gold300, gold500, gold600],
  );
}

class AppRadii {
  AppRadii._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 18;
  static const double lg = 24;
  static const double xl = 32;
  static const double pill = 999;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> soft = [
    BoxShadow(
      color: AppColors.ink900.withValues(alpha: 0.06),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> warm = [
    BoxShadow(
      color: AppColors.orange600.withValues(alpha: 0.22),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> green = [
    BoxShadow(
      color: AppColors.green700.withValues(alpha: 0.20),
      blurRadius: 24,
      offset: const Offset(0, 10),
    ),
  ];
}
