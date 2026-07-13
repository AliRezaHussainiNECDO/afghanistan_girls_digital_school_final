import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// انیمیشن‌های انتقال بین صفحات — به‌جای تعویض ناگهانی، صفحهٔ جدید با
/// محو‌شدن ملایم + کمی لغزش از پایین وارد می‌شود تا حس حرکت نرم و مدرن
/// به کل اپ بدهد (بخش درخواست «انیمیشن‌های زیبا و جذاب»).
CustomTransitionPage<void> fadeSlidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 340),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.04),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

/// انتقال محوشونده‌ی ساده (بدون لغزش) — برای دیالوگ‌مانندها/صفحات سطح بالا
/// مثل صفحهٔ ورود که نباید جهت‌دار به‌نظر برسد.
CustomTransitionPage<void> fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 200),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}
