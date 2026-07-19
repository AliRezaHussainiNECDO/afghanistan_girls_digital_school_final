import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../chat/data/datasources/chat_local_datasource.dart';
import '../../../../chat/domain/entities/chat_entities.dart';
import '../../../../chat/domain/usecases/chat_usecases.dart';
import '../../../../chat/presentation/providers/chat_providers.dart';
import '../../../../chat/presentation/screens/chat_thread_screen.dart' show VoiceBubble;
import '../../../../chat/presentation/widgets/chat_ui_helpers.dart';
import '../../../../../core/localization/app_localizations.dart';

/// نمای نظارتی یک گفتگو برای مدیر — بخش ۱۰.۴ سند:
///   • هر پیام با هویت واقعی فرستنده (نام + صنف + ساعت) نمایش داده می‌شود.
///   • پیام‌های flag‌شده برجسته‌اند و مدیر همین‌جا تأیید/رد می‌کند
///     (بخش ۱۰.۱الف: پیام flag‌شده تا تأیید Admin به گیرنده نمی‌رسد).
///   • در گفتگوهای «شاگرد ↔ مدیریت»، مدیر می‌تواند مستقیم پاسخ بدهد.
class AdminChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const AdminChatThreadScreen({super.key, required this.conversationId});

  @override
  ConsumerState<AdminChatThreadScreen> createState() => _AdminChatThreadScreenState();
}

class _AdminChatThreadScreenState extends ConsumerState<AdminChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    ref.invalidate(adminMessagesProvider(widget.conversationId));
    ref.invalidate(adminConversationInfoProvider(widget.conversationId));
    ref.invalidate(classChatSummariesProvider);
    ref.invalidate(adminInboxProvider);
  }

  Future<void> _review(PeerMessage message, bool approve) async {
    await ref.read(reviewMessageUseCaseProvider).call(ReviewMessageParams(
        conversationId: widget.conversationId, messageId: message.id, approve: approve));
    if (!mounted) return;
    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(approve
          ? context.tr('adminChatThread.approvedSnack')
          : context.tr('adminChatThread.rejectedSnack')),
    ));
  }

  Future<void> _sendReply() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    await ref.read(sendAdminReplyUseCaseProvider).call(
        SendAdminReplyParams(conversationId: widget.conversationId, text: text));
    if (!mounted) return;
    _refresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final infoAsync = ref.watch(adminConversationInfoProvider(widget.conversationId));
    final messagesAsync = ref.watch(adminMessagesProvider(widget.conversationId));
    final scheme = Theme.of(context).colorScheme;
    final info = infoAsync.valueOrNull;
    final isSupport = info?.isAdminSupport ?? widget.conversationId.startsWith('admin_');

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            isSupport
                ? ChatAvatar(name: info?.title ?? '', size: 38)
                : Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: AppColors.heroGradient,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: const Icon(Icons.visibility_rounded,
                        color: Colors.white, size: 20),
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(info?.title ?? context.tr('adminChatThread.reviewFallbackTitle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
                  if (info != null)
                    Text(
                      isSupport
                          ? context.tr('adminChatThread.classWithAdminNote', {'className': info.className})
                          : info.className,
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // نوار حالت نظارتی
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: isSupport ? AppColors.green50 : AppColors.orange50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(isSupport ? Icons.support_agent_rounded : Icons.visibility_rounded,
                    size: 13, color: isSupport ? AppColors.green600 : AppColors.orange600),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    isSupport
                        ? context.tr('adminChatThread.respondingAsAdmin')
                        : context.tr('adminChatThread.readOnlyNotice'),
                    style: TextStyle(
                        fontSize: 10.5,
                        color: isSupport ? AppColors.green700 : AppColors.orange700),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(error: e),
              data: (messages) => ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  final showDate = i == 0 ||
                      dateLabelFa(context, messages[i - 1].timestamp) != dateLabelFa(context, m.timestamp);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showDate) DateSeparator(date: m.timestamp),
                      AdminMessageCard(
                        message: m,
                        onReview: m.isPendingReview ? (approve) => _review(m, approve) : null,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (isSupport)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        textInputAction: TextInputAction.send,
                        decoration:
                            InputDecoration(hintText: context.tr('adminChatThread.replyHint')),
                        onSubmitted: (_) => _sendReply(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      decoration: const BoxDecoration(
                          gradient: AppColors.successGradient, shape: BoxShape.circle),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white),
                        onPressed: _sendReply,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// کارت پیام در نمای نظارتی — همیشه با هویت واقعی فرستنده.
class AdminMessageCard extends StatelessWidget {
  final PeerMessage message;
  final void Function(bool approve)? onReview;
  const AdminMessageCard({super.key, required this.message, this.onReview});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = message;
    final fromAdmin = m.senderId == kAdminUserId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: m.isPendingReview
            ? AppColors.danger.withValues(alpha: 0.06)
            : (fromAdmin ? AppColors.green50 : scheme.surfaceContainerLowest),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: m.isPendingReview
              ? AppColors.danger.withValues(alpha: 0.5)
              : (fromAdmin ? AppColors.green100 : scheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChatAvatar(name: m.senderName, isAdmin: fromAdmin, size: 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // هویت واقعی: نام فرستنده + صنف
                    Text(m.senderName,
                        style:
                            const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    if (m.senderClassName.isNotEmpty)
                      Text(m.senderClassName,
                          style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.green600,
                              fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text(clockFa(m.timestamp),
                  style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 8),
          if (m.kind == MessageKind.voice)
            VoiceBubble(message: m, fromMe: false)
          else
            Text(m.body, style: const TextStyle(height: 1.5, fontSize: 13.5)),
          if (m.flagged) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.flag_rounded, size: 13, color: AppColors.danger),
                const SizedBox(width: 4),
                Text(
                  switch (m.reviewStatus) {
                    MessageReviewStatus.pending =>
                      context.tr('adminChatThread.pendingReviewNotice'),
                    MessageReviewStatus.approved => context.tr('adminChatThread.approvedNotice'),
                    MessageReviewStatus.rejected => context.tr('adminChatThread.rejectedNotice'),
                    _ => '',
                  },
                  style: const TextStyle(fontSize: 10.5, color: AppColors.danger),
                ),
              ],
            ),
          ],
          if (onReview != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green600,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => onReview!(true),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: Text(context.tr('adminChatThread.approveAndDeliver'), style: const TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onPressed: () => onReview!(false),
                    icon: const Icon(Icons.block_rounded, size: 16),
                    label: Text(context.tr('adminChatThread.rejectMessage'), style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
