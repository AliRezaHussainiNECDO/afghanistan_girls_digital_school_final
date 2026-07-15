import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/user_avatar.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../providers/user_management_providers.dart';

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('admin.users'),
      role: AppUserRole.superAdmin,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Material(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(AppRoutes.adminStudents),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.school_rounded, color: scheme.onPrimaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('admin.students'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onPrimaryContainer)),
                            Text(context.tr('admin.studentsSubtitle'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onPrimaryContainer)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left_rounded,
                          color: scheme.onPrimaryContainer),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── مدیریت استادان (هم‌الگو با مدیریت شاگردان — بخش ۱۵.۲ سند) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: scheme.secondaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(AppRoutes.adminInstructors),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.co_present_rounded, color: scheme.onSecondaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('admin.instructors'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onSecondaryContainer)),
                            Text(context.tr('admin.instructorsSubtitle'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onSecondaryContainer)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left_rounded,
                          color: scheme.onSecondaryContainer),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ── مدیریت والدین (بخش جدید — هم‌الگو با شاگردان/استادان) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Material(
              color: scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => context.push(AppRoutes.adminParents),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.family_restroom_rounded, color: scheme.onTertiaryContainer),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(context.tr('admin.parents'),
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: scheme.onTertiaryContainer)),
                            Text(context.tr('admin.parentsSubtitle'),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: scheme.onTertiaryContainer)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left_rounded,
                          color: scheme.onTertiaryContainer),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: context.tr('common.search'),
              ),
              onChanged: (v) => ref.read(adminUserSearchQueryProvider.notifier).state = v,
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(message: e.toString()),
              data: (users) => ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: users.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final u = users[i];
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      bo