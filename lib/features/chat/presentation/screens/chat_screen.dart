import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../domain/entities/chat_entities.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_ui_helpers.dart';

/// فهرست گفتگوهای شاگرد — چت دو نفره با هم‌صنفی‌ها + گفتگو با مدیریت.
/// طراحی مدرن: هدر صنف، جستجو، آواتار گرادیانی، زمان نسبی و نشان نخوانده.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  String _query = '';

  Future<void> _openNewChatSheet() async {
    final classmateId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _ClassmatesSheet(),
    );
    if (classmateId == null || !mounted) return;
    final result = await ref.read(startConversationUseCaseProvider).call(classmateId);
    if (!mounted) return;
    result.fold(
      (f) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(f.message))),
      (conversationId) {
        ref.invalidate(conversationsProvider);
        context.push(AppRoutes.chatThread(conversationId));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final classmatesAsync = ref.watch(classmatesProvider);
    final scheme = Theme.of(context).colorScheme;
    final className = classmatesAsync.maybeWhen(
      data: (list) => list.isEmpty ? '' : list.first.className,
      orElse: () => '',
    );

    return AppScaffold(
      title: context.tr('chat.conversations'),
      role: AppUserRole.student,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewChatSheet,
        backgroundColor: AppColors.orange600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_comment_rounded),
        label: Text(context.tr('chat.newChat')),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(conversationsProvider),
        child: conversationsAsync.when(
          loading: () => const LoadingView(),
          error: (e, st) => ErrorView(message: e.toString()),
          data: (conversations) {
            final filtered = _query.trim().isEmpty
                ? conversations
                : conversations
                    .where((c) =>
                        c.peerName.contains(_query.trim()) ||
                        c.lastMessage.contains(_query.trim()))
                    .toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                // --- هدر صنف: شفافیت دربارهٔ نظارت (بخش ۲۰ سند) ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradientWarm,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    boxShadow: AppShadows.soft,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.school_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              className.isEmpty ? context.tr('chat.myClass') : className,
                              style: const TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              context.tr('chat.monitoredNotice'),
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified_user_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),
                const SizedBox(height: 14),

                // --- جستجو ---
                TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: context.tr('chat.searchHint'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: scheme.surfaceContainerLowest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      borderSide: BorderSide(color: scheme.outlineVariant),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48),
                    child: Column(
                      children: [
                        Icon(Icons.forum_rounded, size: 56, color: scheme.outlineVariant),
                        const SizedBox(height: 12),
                        Text(context.tr('chat.empty'),
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                else
                  for (final (i, c) in filtered.indexed) ...[
                    _ConversationTile(conversation: c)
                        .animate(delay: (40 * i).ms)
                        .fadeIn(duration: 280.ms)
                        .slideY(begin: 0.06),
                    const SizedBox(height: 8),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final PeerConversation conversation;
  const _ConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = conversation;
    return Material(
      color: scheme.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        onTap: () => context.push(AppRoutes.chatThread(c.id)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.lg),
            border: Border.all(
                color: c.unreadCount > 0 ? AppColors.orange200 : scheme.outlineVariant),
          ),
          child: Row(
            children: [
              ChatAvatar(name: c.peerName, isAdmin: c.isAdmin, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.peerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text(relativeTimeFa(c.lastMessageAt),
                            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Expanded(
                          child: Text(c.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                        ),
                        if (c.unreadCount > 0) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                                gradient: AppColors.heroGradient,
                                borderRadius: BorderRadius.circular(AppRadii.pill)),
                            child: Text('${c.unreadCount}',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ],
                    ),
                    if (c.isAdmin) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.green50,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: Border.all(color: AppColors.green100),
                        ),
                        child: Text(context.tr('chat.adminBadge'),
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.green700,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// برگهٔ انتخاب هم‌صنفی برای شروع گفتگوی جدید.
class _ClassmatesSheet extends ConsumerWidget {
  const _ClassmatesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classmatesAsync = ref.watch(classmatesProvider);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                    color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                      gradient: AppColors.heroGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 10),
                Text(context.tr('chat.classmates'),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 6),
            Text(context.tr('chat.classmatesHint'),
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            Flexible(
              child: classmatesAsync.when(
                loading: () => const Padding(
                    padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (e, st) => Padding(
                    padding: const EdgeInsets.all(16), child: Text(e.toString())),
                data: (classmates) => classmates.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(child: Text(context.tr('chat.noClassmates'))),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: classmates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, i) {
                          final cm = classmates[i];
                          return Material(
                            color: scheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(AppRadii.md),
                              onTap: () => Navigator.of(context).pop(cm.id),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(
                                  children: [
                                    ChatAvatar(name: cm.name, size: 42, avatarUrl: cm.avatarUrl),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(cm.name,
                                              style:
                                                  const TextStyle(fontWeight: FontWeight.w700)),
                                          Text(cm.className,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: scheme.onSurfaceVariant)),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chat_bubble_outline_rounded,
                                        size: 18, color: scheme.primary),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
