import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../seminars/presentation/providers/seminars_providers.dart';
import '../../../seminars/presentation/widgets/seminar_card.dart';

/// سمینارهای ویژهٔ والدین — والد فقط سمینارهایی با مخاطب «والدین» را
/// می‌بیند (طبق بخش ۱۳ب سند: دعوت به سمینارهای مرتبط با والدین)،
/// یک‌بار ثبت‌نام می‌کند و در زمان جلسه به ویدیو کنفرانس می‌پیوندد.
class ParentSeminarsScreen extends ConsumerWidget {
  const ParentSeminarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seminarsAsync = ref.watch(parentSeminarsProvider);
    final userId = ref.watch(authSessionProvider)?.id ?? '';

    return AppScaffold(
      title: context.tr('parent.seminars'),
      role: AppUserRole.parent,
      body: seminarsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (seminars) {
          if (seminars.isEmpty) {
            return EmptyView(
              message: context.tr('seminars.noSeminars'),
              icon: Icons.family_restroom_rounded,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(parentSeminarsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // بنر معرفی بخش
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.successGradient,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: AppShadows.green,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.family_restroom_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          context.tr('parent.seminarsIntro'),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12.5, height: 1.6),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.1, end: 0),
                const SizedBox(height: 16),
                for (var i = 0; i < seminars.length; i++) ...[
                  SeminarCard(
                    seminar: seminars[i],
                    userId: userId,
                    index: i,
                    refreshProvider: parentSeminarsProvider,
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
