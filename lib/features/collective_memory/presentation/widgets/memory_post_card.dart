import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/memory_post.dart';
import '../../domain/usecases/collective_memory_usecases.dart';
import '../providers/collective_memory_providers.dart';
import '../utils/time_ago.dart';
import 'emoji_picker_sheet.dart';
import 'memory_avatar.dart';
import 'memory_comments_sheet.dart';
import 'memory_composer_sheet.dart';

/// چند ایموجی ثابت رایج برای واکنش سریع — به‌جای Picker پیچیده، همیشه
/// روی هر پست دیده می‌شوند (منطق ساده و سریع، طبق درخواست کاربر).
const List<String> kQuickReactions = ['❤️', '🌸', '💪', '🙏', '😢', '👏'];

class MemoryPostCard extends ConsumerWidget {
  final MemoryPost post;
  const MemoryPostCard({super.key, required this.post});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف این روایت؟'),
        content: const Text('این روایت و همهٔ کامنت‌های آن برای همیشه حذف می‌شود.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('انصراف')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(deletePostUseCaseProvider).call(post.id);
      ref.read(memoryPostsRefreshProvider.notifier).state++;
    }
  }

  void _openImageViewer(BuildContext context, List<String> images, int startIndex) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          height: 480,
          child: PageView.builder(
            controller: PageController(initialPage: startIndex),
            itemCount: images.length,
            itemBuilder: (context, i) => InteractiveViewer(
              child: Image.memory(base64Decode(images[i]), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authSessionProvider);
    final isAdmin = user?.role == AppUserRole.superAdmin;
    final canModify = user != null && (user.id == post.authorId || isAdmin);
    final commentCountAsync = ref.watch(memoryCommentCountProvider(post.id));

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: AppShadows.soft,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                MemoryAvatar(
                  avatarBase64: post.authorAvatarBase64,
                  name: post.authorName,
                  isAdmin: post.authorIsAdmin,
                  size: 42,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(post.authorName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                          ),
                          if (post.authorIsAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(AppRadii.pill),
                              ),
                              child: Text('مدیریت',
                                  style: TextStyle(fontSize: 10, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        post.isEdited ? '${timeAgoFa(post.createdAt)} · ویرایش‌شده' : timeAgoFa(post.createdAt),
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (canModify)
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant, size: 20),
                    onSelected: (value) {
                      if (value == 'edit') {
                        showMemoryComposerSheet(context, existing: post);
                      } else if (value == 'delete') {
                        _confirmDelete(context, ref);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'edit', child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('ویرایش'),
                      ])),
                      PopupMenuItem(value: 'delete', child: Row(children: [
                        Icon(Icons.delete_outline_rounded, size: 18, color: scheme.error),
                        const SizedBox(width: 8),
                        Text('حذف', style: TextStyle(color: scheme.error)),
                      ])),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(post.body, style: const TextStyle(fontSize: 14, height: 1.6)),
            if (post.imagesBase64.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: post.imagesBase64.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: () => _openImageViewer(context, post.imagesBase64, i),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      child: Image.memory(base64Decode(post.imagesBase64[i]),
                          width: 130, height: 110, fit: BoxFit.cover),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            Builder(builder: (context) {
              // ایموجی‌های سریع + هر ایموجی دیگری که کاربران با Picker فرستاده‌اند.
              final visibleEmojis = <String>[
                ...kQuickReactions,
                ...post.reactions.keys.where((e) => !kQuickReactions.contains(e)),
              ];
              Future<void> toggle(String emoji) async {
                if (user == null) return;
                await ref.read(toggleReactionUseCaseProvider).call(
                      ToggleReactionParams(postId: post.id, emoji: emoji, userId: user.id),
                    );
                ref.read(memoryPostsRefreshProvider.notifier).state++;
              }

              return Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ...visibleEmojis.map((emoji) {
                    final count = post.reactions[emoji]?.length ?? 0;
                    final reacted = user != null && post.hasUserReacted(user.id, emoji);
                    return InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                      onTap: user == null ? null : () => toggle(emoji),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: reacted ? scheme.primaryContainer : scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          border: reacted ? Border.all(color: scheme.primary, width: 1.2) : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            if (count > 0) ...[
                              const SizedBox(width: 4),
                              Text('$count',
                                  style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: reacted ? scheme.onPrimaryContainer : scheme.onSurfaceVariant)),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                  // دکمهٔ «+» — باز کردن انتخابگر کامل ایموجی.
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    onTap: user == null
                        ? null
                        : () async {
                            final emoji = await showEmojiPickerSheet(context);
                            if (emoji != null) await toggle(emoji);
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Icon(Icons.add_reaction_outlined, size: 16, color: scheme.primary),
                    ),
                  ),
                ],
              );
            }),
            const SizedBox(height: 10),
            Divider(height: 1, color: scheme.outlineVariant),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.md),
              onTap: () => showMemoryCommentsSheet(context, post: post),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.mode_comment_outlined, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Text(
                      commentCountAsync.when(
                        data: (c) => c == 0 ? 'اولین نظر را بنویس' : '$c نظر · مشاهده و گفت‌وگو',
                        loading: () => 'در حال بارگذاری...',
                        error: (_, __) => 'نظرات',
                      ),
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.06, end: 0, duration: 320.ms, curve: Curves.easeOutCubic);
  }
}
