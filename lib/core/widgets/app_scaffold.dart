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
