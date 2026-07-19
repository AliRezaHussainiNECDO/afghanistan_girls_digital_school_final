import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_ui_helpers.dart';

/// گفتگوی «ارتباط با مدیریت» — یک مقصد ثابت و همیشه در دسترس برای هر نقشی
/// (والد/استاد؛ برای شاگرد همین گفتگو از داخل «چت» هم در دسترس است) تا
/// مستقیماً با مدیریت و پشتیبانی مکتب در تماس باشند.
///
/// رفع اشکال هماهنگی: قبلاً هیچ راهی برای والد/استاد وجود نداشت که با
/// مدیریت مکتب پیام‌رسانی کنند؛ حالا از همان زیرساخت واقعیِ گفتگوی
/// «کاربر ↔ مدیریت» (که قبلاً فقط برای شاگرد در دسترس بود) استفاده می‌شود.
class ContactAdminScreen extends ConsumerStatefulWidget {
  const ContactAdminScreen({super.key});

  @override
  ConsumerState<ContactAdminScreen> createState() => _ContactAdminScreenState();
}

class _ContactAdminScreenState extends ConsumerState<ContactAdminScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  /// پیامِ در حال ریپلای (migration 0031).
  PeerMessage? _replyingTo;

  /// به‌روزرسانی زنده — تا وقتی صفحه باز است، پاسخ مدیریت همان لحظه می‌رسد.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final id = ref.read(contactAdminConversationProvider).valueOrNull;
      if (id != null) ref.invalidate(messagesProvider(id));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent + 120,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send(String conversationId, String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    final replyToId = _replyingTo?.id;
    setState(() {
      _sending = true;
      _replyingTo = null;
    });
    try {
      await ref.read(sendPeerMessageUseCaseProvider).call(SendPeerMessageParams(
          conversationId: conversationId, text: text, replyToId: replyToId));
      if (!mounted) return;
      ref.invalidate(messagesProvider(conversationId));
      _scrollToEnd();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authSessionProvider)?.role ?? AppUserRole.parent;
    final convIdAsync = ref.watch(contactAdminConversationProvider);

    return AppScaffold(
      title: context.tr('chat.contactAdmin'),
      role: role,
      body: convIdAsync.when(
        loading: () => const _LoadingStage(),
        error: (e, st) => ErrorView(error: e),
        data: (conversationId) => _Thread(
          conversationId: conversationId,
          controller: _controller,
          scroll: _scroll,
          sending: _sending,
          replyingTo: _replyingTo,
          onReply: (m) => setState(() => _replyingTo = m),
          onCancelReply: () => setState(() => _replyingTo = null),
          onSend: (text) => _send(conversationId, text),
        ),
      ),
    );
  }
}

class _LoadingStage extends StatelessWidget {
  const _LoadingStage();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class _Thread extends ConsumerStatefulWidget {
  final String conversationId;
  final TextEditingController controller;
  final ScrollController scroll;
  final bool sending;
  final PeerMessage? replyingTo;
  final ValueChanged<PeerMessage> onReply;
  final VoidCallback onCancelReply;
  final ValueChanged<String> onSend;

  const _Thread({
    required this.conversationId,
    required this.controller,
    required this.scroll,
    required this.sending,
    required this.replyingTo,
    required this.onReply,
    required this.onCancelReply,
    required this.onSend,
  });

  @override
  ConsumerState<_Thread> createState() => _ThreadState();
}

class _ThreadState extends ConsumerState<_Thread> {
  int _lastCount = -1;

  String get conversationId => widget.conversationId;
  TextEditingController get controller => widget.controller;
  ScrollController get scroll => widget.scroll;
  bool get sending => widget.sending;
  ValueChanged<String> get onSend => widget.onSend;

  /// پرش به پیام اصلیِ یک نقل‌قول — جای تقریبی آن در فهرست.
  void _scrollToMessage(List<PeerMessage> messages, String messageId) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1 || !scroll.hasClients) return;
    final fraction = messages.length <= 1 ? 0.0 : idx / (messages.length - 1);
    scroll.animateTo(
      scroll.position.maxScrollExtent * fraction,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(conversationId));
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: AppColors.successGradient,
            borderRadius: BorderRadius.circular(AppRadii.lg),
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.support_agent_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(context.tr('chat.adminSupportTitle'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(context.tr('chat.adminSupportSubtitle'),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08),
        Expanded(
          child: messagesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => ErrorView(error: e),
            data: (messages) {
              if (messages.isEmpty) return _intro(context);
              // فقط با آمدن پیام تازه به انتها بپر — نه با هر تازه‌سازی زنده.
              if (messages.length != _lastCount) {
                _lastCount = messages.length;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (scroll.hasClients) scroll.jumpTo(scroll.position.maxScrollExtent);
                });
              }
              final byId = {for (final m in messages) m.id: m};
              return ListView.builder(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                itemCount: messages.length,
                itemBuilder: (context, i) {
                  final m = messages[i];
                  return SwipeToReply(
                    onReply: () => widget.onReply(m),
                    child: GestureDetector(
                      onLongPress: () => widget.onReply(m),
                      child: _Bubble(
                        msg: m,
                        repliedTo: m.replyToId != null ? byId[m.replyToId] : null,
                        onQuoteTap: m.replyToId != null
                            ? () => _scrollToMessage(messages, m.replyToId!)
                            : null,
                      ),
                    ),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: 0.08);
                },
              );
            },
          ),
        ),
        // پیش‌نمایش «در پاسخ به …» — با انیمیشن ظاهر/پنهان می‌شود.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: widget.replyingTo == null
              ? const SizedBox.shrink()
              : ReplyComposerBar(
                  replyingTo: widget.replyingTo!,
                  onCancel: widget.onCancelReply,
                ),
        ),
        if (sending)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text(context.tr('chat.sending'), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ]),
          ),
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: onSend,
                    decoration: InputDecoration(
                      hintText: context.tr('chat.typeMessage'),
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
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: sending ? null : () => onSend(controller.text),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _intro(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(gradient: AppColors.successGradient, shape: BoxShape.circle),
            child: const Icon(Icons.forum_rounded, color: Colors.white, size: 38),
          ),
        ).animate().scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.easeOutBack),
        const SizedBox(height: 18),
        Text(context.tr('chat.noConversationYet'),
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onSurface)),
        const SizedBox(height: 8),
        Text(context.tr('chat.sendFirstMessage'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.7, color: scheme.onSurfaceVariant)),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final PeerMessage msg;

  /// پیامِ نقل‌شده (اگر این پیام ریپلای باشد).
  final PeerMessage? repliedTo;
  final VoidCallback? onQuoteTap;
  const _Bubble({required this.msg, this.repliedTo, this.onQuoteTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fromMe = msg.fromMe;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: fromMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!fromMe) ...[
            ChatAvatar(name: msg.senderName, isAdmin: true, size: 30),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: fromMe ? scheme.primary : scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadii.lg),
                  topRight: const Radius.circular(AppRadii.lg),
                  bottomLeft: Radius.circular(fromMe ? AppRadii.lg : AppRadii.xs),
                  bottomRight: Radius.circular(fromMe ? AppRadii.xs : AppRadii.lg),
                ),
                border: fromMe ? null : Border.all(color: scheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (msg.replyToId != null)
                    QuotedMessage(original: repliedTo, onGradient: fromMe, onTap: onQuoteTap),
                  Text(
                    msg.body,
                    style: TextStyle(
                        height: 1.6, color: fromMe ? scheme.onPrimary : scheme.onSurface),
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
