import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../chat/presentation/providers/chat_providers.dart';
import '../../../../chat/presentation/widgets/chat_ui_helpers.dart';

/// گفتگوهای یک صنف از دید مدیر — هر گفتگو با هویت واقعی هر دو شاگرد
/// («فاطمه رضایی ↔ مریم احمدی») نمایش داده می‌شود (بخش ۱۰.۴ سند).
class AdminClassChatsScreen extends ConsumerWidget {
  final String classId;
  const AdminClassChatsScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(classConversationsProvider(classId));
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: conversationsAsync.maybeWhen(
        data: (list) => list.isEmpty ? context.tr('classChats.title') : list.first.className,
        orElse: () => context.tr('classChats.title'),
      ),
      role: AppUserRole.superAdmin,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(classConversationsProvider(classId)),
        child: conversationsAsync.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(error: e),
          data: (conversations) => conversations.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 80),
                    Icon(Icons.forum_rounded, size: 56, color: scheme.outlineVariant),
                    const SizedBox(height: 12),
                    Center(
                        child: Text(context.tr('classChats.emptyState'),
                            style: TextStyle(color: scheme.onSurfaceVariant))),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = conversations[i];
                    return Material(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadii.lg),
                        onTap: () => context.push(AppRoutes.adminChatThread(c.id)),
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(
                                color: c.flaggedPendingCount > 0
                                    ? AppColors.danger.withValues(alpha: 0.45)
                                    : scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              c.isAdminSupport
                                  ? const ChatAvatar(name: '', isAdmin: true, size: 44)
                                  : ChatAvatar(name: c.title, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            c.isAdminSupport
                                                ? context.tr('classChats.titleWithAdmin', {'title': c.title})
                                                : c.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5),
                                          ),
                                        ),
                                        Text(relativeTimeFa(context, c.lastMessageAt),
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                color: scheme.onSurfaceVariant)),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(c.lastMessage,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: scheme.onSurfaceVariant)),
                                    const SizedBox(height: 5),
                                    Wrap(
                                      spacing: 8,
                                      children: [
                                        Text(context.tr('classChats.messageCountLabel', {'count': '${c.messageCount}'}),
                                            style: TextStyle(
                                                fontSize: 10.5,
                                                color: scheme.onSurfaceVariant)),
                                        if (c.flaggedPendingCount > 0)
                                          Text(
                                              '⚑ ${context.tr('classChats.pendingReviewLabel', {'count': '${c.flaggedPendingCount}'})}',
                                              style: const TextStyle(
                                                  fontSize: 10.5,
                                                  color: AppColors.danger,
                                                  fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ).animate(delay: (50 * i).ms).fadeIn(duration: 260.ms).slideY(begin: 0.05);
                  },
                ),
        ),
      ),
    );
  }
}
