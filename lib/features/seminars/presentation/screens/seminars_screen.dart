import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/seminars_providers.dart';
import '../widgets/seminar_card.dart';

/// سمینارهای شاگرد — ثبت‌نام فقط یک‌بار + پیوستن به ویدیو کنفرانس زنده.
class SeminarsScreen extends ConsumerWidget {
  const SeminarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seminarsAsync = ref.watch(upcomingSeminarsProvider);
    final userId = ref.watch(authSessionProvider)?.id ?? '';

    return AppScaffold(
      title: context.tr('seminars.upcoming'),
      role: AppUserRole.student,
      body: seminarsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(upcomingSeminarsProvider),
            ),
        data: (seminars) {
          if (seminars.isEmpty) {
            return EmptyView(
              message: context.tr('seminars.noSeminars'),
              icon: Icons.groups_outlined,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(upcomingSeminarsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: seminars.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, i) => SeminarCard(
                seminar: seminars[i],
                userId: userId,
                index: i,
                refreshProvider: upcomingSeminarsProvider,
              ),
            ),
          );
        },
      ),
    );
  }
}
