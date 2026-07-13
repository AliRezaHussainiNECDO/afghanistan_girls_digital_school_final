import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../domain/entities/memory_comment.dart';
import '../../domain/entities/memory_post.dart';
import '../../domain/usecases/collective_memory_usecases.dart';
import '../providers/collective_memory_providers.dart';
import '../utils/time_ago.dart';
import 'memory_avatar.dart';

/// ورق کامنت‌ها — پشتیبانی از کامنت و ریپلای روی کامنت (یک سطح تودرتو،
/// طبق درخواست کاربر: «کمنت و ریپلای کمنت»).
Future<void> showMemoryCommentsSheet(BuildContext context, {required MemoryPost post}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MemoryCommentsSheet(post: post),
  );
}

class _MemoryCommentsSheet extends ConsumerStatefulWidget {
  final MemoryPost post;
  const _MemoryCommentsSheet({required this.post});

  @override
  ConsumerState<_MemoryCommentsSheet> createState() => _MemoryCommentsSheetState();
}

class _MemoryCommentsSheetState extends ConsumerState<_MemoryCommentsSheet> {
  final TextEditingController _controller = TextEditingController();
  String? _replyToId;
  String? _replyToName;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startReply(MemoryComment c) {
    setState(() {
      _replyToId = c.id;
      _replyToName = c.authorName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final user = ref.read(authSessionProvider);
    if (user == null) return;
    setState(() => _sending = true);
    try {
      final photoBytes = ref.read(profilePhotoProvider);
      await ref.read(addCommentUseCaseProvider).call(AddCommentParams(
            postId: widget.post.id,
            parentCommentId: _replyToId,
            authorId: user.id,
            authorName: user.displayName,
            authorIsAdmin: user.role == AppUserRole.superAdmin,
            authorAvatarBase64: photoBytes != null ? base64Encode(photoBytes) : null,
            body: text,
          ));
      ref.read(memoryPostsRefreshProvider.notifier).state++;
      _controller.clear();
      _cancelReply();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String commentId) async {
    await ref.read(deleteCommentUseCaseProvider).call(commentId);
    ref.read(memoryPostsRefreshProvider.notifier).state++;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = ref.watch(authSessionProvider);
    final isAdmin = user?.role == AppUserRole.superAdmin;
    final commentsAsync = ref.watch(memoryCommentsProvider(widget.post.id));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.mode_comment_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    const Text('گفت‌وگو دربارهٔ این روایت', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: scheme.outlineVariant),
              Expanded(
                child: commentsAsync.when(
                  data: (comments) {
                    if (comments.isEmpty) {
                      return Center(
                        child: Text('هنوز نظری ثبت نشده — اولین نفر باش.',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      );
                    }
                    final topLevel = comments.where((c) => !c.isReply).toList();
                    Map<String, List<MemoryComment>> repliesByParent = {};
                    for (final c in comments.where((c) => c.isReply)) {
                      repliesByParent.putIfAbsent(c.parentCommentId!, () => []).add(c);
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      itemCount: topLevel.length,
                      itemBuilder: (context, i) {
                        final c = topLevel[i];
                        final replies = repliesByParent[c.id] ?? const <MemoryComment>[];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _CommentTile(
                                comment: c,
                                canDelete: user != null && (user.id == c.authorId || isAdmin),
                                onReply: () => _startReply(c),
                                onDelete: () => _delete(c.id),
                              ),
                              if (replies.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 28, top: 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: replies
                                        .map((r) => Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: _CommentTile(
                                                comment: r,
                                                canDelete: user != null && (user.id == r.authorId || isAdmin),
                                                onReply: () => _startReply(c),
                                                onDelete: () => _delete(r.id),
                                                isReply: true,
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, __) => Center(child: Text('خطا در بارگذاری نظرات', style: TextStyle(color: scheme.error))),
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              if (_replyToId != null)
                Container(
                  width: double.infinity,
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: Text('در پاسخ به $_replyToName', style: const TextStyle(fontSize: 12))),
                      InkWell(onTap: _cancelReply, child: const Icon(Icons.close_rounded, size: 16)),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textDirection: TextDirection.rtl,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: user == null ? 'برای نظر دادن وارد شوید' : 'نظر خود را بنویس...',
                          filled: true,
                          fillColor: scheme.surfaceContainerLow,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.pill),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        enabled: user != null && !_sending,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                      child: IconButton(
                        onPressed: (user == null || _sending) ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      ),
                    ),
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

class _CommentTile extends StatelessWidget {
  final MemoryComment comment;
  final bool canDelete;
  final bool isReply;
  final VoidCallback onReply;
  final VoidCallback onDelete;
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onReply,
    required this.onDelete,
    this.isReply = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              MemoryAvatar(
                avatarBase64: comment.authorAvatarBase64,
                name: comment.authorName,
                isAdmin: comment.authorIsAdmin,
                size: 26,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(comment.authorName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                    if (comment.authorIsAdmin) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadii.pill)),
                        child: Text('مدیریت', style: TextStyle(fontSize: 9, color: scheme.onPrimaryContainer, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ],
                ),
              ),
              Text(timeAgoFa(comment.createdAt), style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Text(comment.body, style: const TextStyle(fontSize: 13, height: 1.5)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (!isReply)
                InkWell(
                  onTap: onReply,
                  child: Text('پاسخ', style: TextStyle(fontSize: 11.5, color: scheme.primary, fontWeight: FontWeight.w700)),
                ),
              const Spacer(),
              if (canDelete)
                InkWell(
                  onTap: onDelete,
                  child: Icon(Icons.delete_outline_rounded, size: 16, color: scheme.error),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
