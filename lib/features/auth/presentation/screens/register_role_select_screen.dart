import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';

class RegisterRoleSelectScreen extends StatelessWidget {
  const RegisterRoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: Text(context.tr('auth.selectRole'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr('auth.selectRole'),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                _RoleCard(
                  title: context.tr('auth.roleStudent'),
                  subtitle: context.tr('auth.registerStudent'),
                  icon: Icons.face_3_rounded,
                  gradient: AppColors.heroGradient,
                  onTap: () => context.push(AppRoutes.registerStudent),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  title: context.tr('auth.roleParent'),
                  subtitle: context.tr('auth.registerParent'),
                  icon: Icons.family_restroom_rounded,
                  gradient: AppColors.successGradient,
                  onTap: () => context.push(AppRoutes.registerParent),
                ),
                const SizedBox(height: 16),
                // استاد سمینار — فقط با کد دعوت ساخته‌شده توسط مدیر (بخش ۲.۲).
                _RoleCard(
                  title: 'استاد سمینار',
                  subtitle: 'فعال‌سازی حساب با کد دعوت مدیریت',
                  icon: Icons.co_present_rounded,
                  gradient: AppColors.heroGradientWarm,
                  onTap: () => context.push(AppRoutes.registerInstructor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(gradient: gradient, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
