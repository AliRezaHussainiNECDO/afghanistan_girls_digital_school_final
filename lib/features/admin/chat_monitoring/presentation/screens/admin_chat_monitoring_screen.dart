import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../chat/presentation/providers/chat_providers.dart';
import '../../../../chat/presentation/widgets/chat_ui_helpers.dart';

/// داشبورد نظارت بر چت — بخش ۱۰.۴ سند: مدیر چت‌های هر صنف را صنف‌به‌صنف
/// می‌بیند و پیام‌های شاگردان به مدیریت با هویت واقعی شاگرد نمایش داده
/// می‌شوند.
class AdminChatMonitoringScreen extends ConsumerWidget {
  const AdminChatMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summariesAsync = ref.watch(classChatSummariesProvider);
    final inboxAsync = ref.watch(adminInboxProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('admin.chatMonitoring'),
      role: AppUserRole.superAdmin,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(classChatSummariesProvider);
          ref.invalidate(adminInboxProvider);
        },
        child: summariesAsync.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(message: e.toString()),
          data: (summaries) {
            final totalFlagged =
                summaries.fold<int>(0, (a, s) => a + s.flaggedPendingCount);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- نوار وضعیت کلی ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: totalFlagged > 0
                        ? const LinearGradient(
                            colors: [AppColors.danger, Color(0xFFB4232A)])
                        : AppColors.successGradient,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        totalFlagged > 0
                            ? Icons.warning_amber_rounded
                            : Icons.verified_user_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          totalFlagged > 0
                              ? '$totalFlagged پیام در انتظار بازبینی شماست'
                              : 'همهٔ پیام‌ها بررسی شده‌اند — وضعیت سالم ✨',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
                const SizedBox(height: 18),

                Text(context.tr('admin.classChats'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                for (final (i, s) in summaries.indexed) ...[
                  Material(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      onTap: () => context.push(AppRoutes.adminClassChats(s.classId)),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadii.lg),
                          border: Border.all(
                              color: s.flaggedPendingCount > 0
                                  ? AppColors.danger.withValues(alpha: 0.45)
                                  : scheme.outlineVariant),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: i.isEven
                                    ? AppColors.heroGradient
                                    : AppColors.successGradient,
                                borderRadius: BorderRadius.circular(AppRadii.md),
                              ),
                              child: const Icon(Icons.school_rounded,
                                  color: Colors.white, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.className,
                                      style: const TextStyle(fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 10,
                                    children: [
                                      _MiniStat(
                                          icon: Icons.groups_rounded,
                                          label: '${s.studentCount} شاگرد'),
                                      _MiniStat(
                                          icon: Icons.forum_rounded,
                                          label: '${s.conversationCount} گفتگو'),
                                      _MiniStat(
                                          icon: Icons.chat_bubble_rounded,
                                          label: '${s.messageCount} پیام'),
                                    ],
                                  ),
                                  if (s.lastActivityAt != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                        'آخرین فعالیت: ${relativeTimeFa(s.lastActivityAt!)}',
                                        style: TextStyle(
                                            fontSize: 10.5,
                                            color: scheme.onSurfaceVariant)),
                                  ],
                                ],
                              ),
                            ),
                            if (s.flaggedPendingCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.danger,
                                  borderRadius: BorderRadius.circular(AppRadii.pill),
                                ),
                                child: Text('${s.flaggedPendingCount} ⚑',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800)),
                              )
                            else
                              Icon(Icons.chevron_left_rounded,
                                  color: scheme.onSurfaceVariant),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: (60 * i).ms).fadeIn(duration: 280.ms).slideY(begin: 0.06),
                  const SizedBox(height: 10),
                ],

                const SizedBox(height: 12),
                Text(context.tr('admin.studentMessages'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 4),
                Text(context.tr('admin.studentMessagesHint'),
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 10),
                inboxAsync.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator())),
                  error: (e, st) => Text(e.toString()),
                  data: (inbox) => inbox.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppRadii.lg),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Center(
                              child: Text('هنوز پیامی از شاگردان نرسیده است.',
                                  style:
                                      TextStyle(color: scheme.onSurfaceVariant))),
                        )
                      : Column(
                          children: [
                            for (final conv in inbox) ...[
                              Material(
                                color: scheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(AppRadii.lg),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppRadii.lg),
                                  onTap: () => context
                                      .push(AppRoutes.adminChatThread(conv.id)),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      borderRadius:
                                          BorderRadius.circular(AppRadii.lg),
                                      border:
                                          Border.all(color: scheme.outlineVariant),
                                    ),
                                    child: Row(
                                      children: [
                                        ChatAvatar(name: conv.title, size: 44),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(conv.title,
                                                        style: const TextStyle(
                                                            fontWeight:
                                                                FontWeight.w700)),
                                                  ),
                                                  Text(
                                                      relativeTimeFa(
                                                          conv.lastMessageAt),
                                                      style: TextStyle(
                                                          fontSize: 10.5,
                                                          color: scheme
                                                              .onSurfaceVariant)),
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              // هویت واقعی شاگرد: نام + صنف
                                              Text(conv.className,
                                                  style: const TextStyle(
                                                      fontSize: 11,
                                                      color: AppColors.green600,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              const SizedBox(height: 2),
                                              Text(conv.lastMessage,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: scheme
                                                          .onSurfaceVariant)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ],
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MiniStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: scheme.onSurfaceVariant),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}
