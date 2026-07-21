import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/usecases/chat_usecases.dart';
import '../providers/chat_providers.dart';
import '../widgets/chat_ui_helpers.dart';

/// رشتهٔ گفتگو (دو نفره با هم‌صنفی یا با مدیریت) — طراحی مدرن با جداکنندهٔ
/// تاریخ، ساعت پیام، وضعیت «در انتظار بازبینی مدیر» و پیام صوتی.
class ChatThreadScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatThreadScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  /// به‌روزرسانی زنده: تا وقتی این صفحه باز است، پیام‌ها هر چند ثانیه از
  /// سرور تازه می‌شوند (Riverpod دادهٔ قبلی را حین تازه‌سازی نگه می‌دارد،
  /// پس هیچ پرش/چشمک‌زدنی دیده نمی‌شود) — پیامِ رسیده همان لحظه ظاهر می‌شود.
  Timer? _pollTimer;
  int _lastMsgCount = -1;

  /// پیامِ در حال ریپلای (migration 0031) — null یعنی حالت عادی.
  PeerMessage? _replyingTo;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      ref.invalidate(messagesProvider(widget.conversationId));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _recordTimer?.cancel();
    _pollTimer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  /// پرش به پیام اصلیِ یک نقل‌قول — جای تقریبی آن در فهرست.
  void _scrollToMessage(List<PeerMessage> messages, String messageId) {
    final idx = messages.indexWhere((m) => m.id == messageId);
    if (idx == -1 || !_scrollController.hasClients) return;
    final fraction = messages.length <= 1 ? 0.0 : idx / (messages.length - 1);
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent * fraction,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// منوی اقدام روی پیام — «ریپلای» برای همه؛ «گزارش تخلف» فقط برای پیام دیگران.
  Future<void> _showMessageActions(PeerMessage m) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: Text(ctx.tr('chat.replyAction')),
              onTap: () => Navigator.pop(ctx, 'reply'),
            ),
            if (!m.fromMe)
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: Text(ctx.tr('chat.reportAction')),
                onTap: () => Navigator.pop(ctx, 'report'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'reply') {
      setState(() => _replyingTo = m);
    } else if (action == 'report') {
      await _showReportSheet(m);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final replyToId = _replyingTo?.id;
    setState(() => _replyingTo = null);
    await ref.read(sendPeerMessageUseCaseProvider).call(SendPeerMessageParams(
        conversationId: widget.conversationId, text: text, replyToId: replyToId));
    if (!mounted) return;
    ref.invalidate(messagesProvider(widget.conversationId));
    ref.invalidate(conversationsProvider);
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    if (_isRecording) return; // جلوگیری از دوبار ضبط هم‌زمان با دابل‌کلیک
    final hasPermission = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('chat.micPermissionRequired'))),
      );
      return;
    }
    String path = '';
    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      if (!mounted) return;
    }
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() => _recordDuration += const Duration(milliseconds: 200));
    });
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _recorder.stop();
    if (!mounted) return;
    setState(() => _isRecording = false);
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final durationMs = _recordDuration.inMilliseconds;
    if (!mounted) return;
    setState(() => _isRecording = false);
    if (path == null || durationMs < 500) return; // خیلی کوتاه — نادیده گرفته شود
    await ref.read(sendVoiceMessageUseCaseProvider).call(
          SendVoiceMessageParams(
            conversationId: widget.conversationId,
            audioUrl: path,
            durationMs: durationMs,
          ),
        );
    if (!mounted) return;
    ref.invalidate(messagesProvider(widget.conversationId));
    ref.invalidate(conversationsProvider);
    _scrollToBottom();
  }

  /// گزارش تخلف — طبق بند ۳ قوانین و شرایط استفاده. با نگه‌داشتن انگشت روی
  /// پیامِ طرف مقابل باز می‌شود.
  Future<void> _showReportSheet(PeerMessage message) async {
    final reasons = [
      context.tr('chat.reportReason1'),
      context.tr('chat.reportReason2'),
      context.tr('chat.reportReason3'),
      context.tr('chat.reportReason4'),
    ];
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text(context.tr('chat.reportReasonPrompt'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            for (final reason in reasons)
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: Text(reason),
                onTap: () => Navigator.of(context).pop(reason),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    await ref
        .read(reportMessageUseCaseProvider)
        .call(ReportMessageParams(messageId: message.id, reason: selected));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('chat.reportSubmitted'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final conversationsAsync = ref.watch(conversationsProvider);
    final scheme = Theme.of(context).colorScheme;

    final conv = conversationsAsync.maybeWhen(
      data: (list) {
        for (final c in list) {
          if (c.id == widget.conversationId) return c;
        }
        return null;
      },
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            ChatAvatar(
                name: conv?.peerName ?? '', isAdmin: conv?.isAdmin ?? false, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(conv?.peerName ?? context.tr('chat.conversations'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  if (conv != null)
                    Text(
                      conv.isAdmin
                          ? context.tr('chat.adminBadge')
                          : conv.peerClassName,
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
          // شفافیت: یادآوری ظریف نظارت مدیریت (بخش ۲۰ سند).
          if (conv != null && !conv.isAdmin)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.green50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_rounded, size: 13, color: AppColors.green600),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(context.tr('chat.monitoredNotice'),
                        style: const TextStyle(fontSize: 10.5, color: AppColors.green700)),
                  ),
                ],
              ),
            ),
          Expanded(
            child: messagesAsync.when(
              loading: () => const LoadingView(),
              error: (e, st) => ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(messagesProvider(widget.conversationId)),
                  ),
              data: (messages) {
                // فقط با آمدن پیام تازه به انتها بپر — نه با هر تازه‌سازی زنده
                // (تا وقتی کاربر مشغول خواندن پیام‌های قبلی است، مزاحم نشود).
                if (messages.length != _lastMsgCount) {
                  _lastMsgCount = messages.length;
                  _scrollToBottom();
                }
                final byId = {for (final m in messages) m.id: m};
                return ListView.builder(
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
                        SwipeToReply(
                          onReply: () => setState(() => _replyingTo = m),
                          child: GestureDetector(
                            onLongPress: () => _showMessageActions(m),
                            child: _MessageBubble(
                              message: m,
                              repliedTo: m.replyToId != null ? byId[m.replyToId] : null,
                              onQuoteTap: m.replyToId != null
                                  ? () => _scrollToMessage(messages, m.replyToId!)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          // پیش‌نمایش «در پاسخ به …» — با انیمیشن ظاهر/پنهان می‌شود.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: _replyingTo == null
                ? const SizedBox.shrink()
                : ReplyComposerBar(
                    replyingTo: _replyingTo!,
                    onCancel: () => setState(() => _replyingTo = null),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _isRecording
                  ? Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: scheme.error),
                          onPressed: _cancelRecording,
                          tooltip: context.tr('common.cancel'),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(color: scheme.error, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _formatDuration(_recordDuration),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          decoration:
                              const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white),
                            onPressed: _stopAndSendRecording,
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            textInputAction: TextInputAction.send,
                            decoration: InputDecoration(hintText: context.tr('chat.typeMessage')),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(Icons.mic_rounded, color: scheme.primary),
                          onPressed: _startRecording,
                          tooltip: context.tr('chat.voiceMessageTooltip'),
                        ),
                        Container(
                          decoration:
                              const BoxDecoration(gradient: AppColors.heroGradient, shape: BoxShape.circle),
                          child: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.white),
                            onPressed: _send,
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _MessageBubble extends StatelessWidget {
  final PeerMessage message;

  /// پیامِ نقل‌شده (اگر این پیام ریپلای باشد) — null یعنی یافت نشد/عادی.
  final PeerMessage? repliedTo;
  final VoidCallback? onQuoteTap;
  const _MessageBubble({required this.message, this.repliedTo, this.onQuoteTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final m = message;
    return Align(
      alignment: m.fromMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: m.fromMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            padding: EdgeInsets.symmetric(
                horizontal: m.kind == MessageKind.voice ? 10 : 14, vertical: 10),
            constraints:
                BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
            decoration: BoxDecoration(
              gradient: m.fromMe ? AppColors.heroGradient : null,
              color: m.fromMe ? null : scheme.surfaceContainer,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(AppRadii.md),
                topRight: const Radius.circular(AppRadii.md),
                bottomLeft: Radius.circular(m.fromMe ? AppRadii.md : 4),
                bottomRight: Radius.circular(m.fromMe ? 4 : AppRadii.md),
              ),
              boxShadow: m.fromMe ? AppShadows.soft : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.replyToId != null)
                  QuotedMessage(
                    original: repliedTo,
                    onGradient: m.fromMe,
                    onTap: onQuoteTap,
                  ),
                m.kind == MessageKind.voice
                    ? VoiceBubble(message: m, fromMe: m.fromMe)
                    : Text(m.body,
                        style: TextStyle(
                            color: m.fromMe ? Colors.white : scheme.onSurface, height: 1.5)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(clockFa(m.timestamp),
                    style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                if (m.fromMe && m.isPendingReview) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.hourglass_top_rounded, size: 11, color: AppColors.gold600),
                  const SizedBox(width: 2),
                  Text(context.tr('chat.pendingReview'),
                      style: const TextStyle(fontSize: 10, color: AppColors.gold600)),
                ] else if (m.fromMe && m.isRejected) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.block_rounded, size: 11, color: AppColors.danger),
                  const SizedBox(width: 2),
                  Text(context.tr('chat.rejectedByAdmin'),
                      style: const TextStyle(fontSize: 10, color: AppColors.danger)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// حباب پیام صوتی — مشترک بین دید شاگرد و دید نظارتی مدیر.
class VoiceBubble extends StatefulWidget {
  final PeerMessage message;
  final bool fromMe;
  const VoiceBubble({super.key, required this.message, required this.fromMe});

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> {
  final _player = AudioPlayer();
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    final url = widget.message.audioUrl;
    if (url == null) return;
    if (_playing) {
      await _player.pause();
      setState(() => _playing = false);
      return;
    }
    try {
      if (kIsWeb || url.startsWith('http') || url.startsWith('blob:')) {
        await _player.play(UrlSource(url));
      } else {
        await _player.play(DeviceFileSource(url));
      }
      setState(() => _playing = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.tr('chat.voicePlaybackFailed'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.fromMe ? Colors.white : Theme.of(context).colorScheme.onSurface;
    final seconds = ((widget.message.durationMs ?? 0) / 1000).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: Icon(_playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
              color: color, size: 32),
          onPressed: _toggle,
        ),
        const SizedBox(width: 6),
        Icon(Icons.graphic_eq_rounded, color: color.withValues(alpha: 0.85), size: 20),
        const SizedBox(width: 8),
        Text('0:${seconds.toString().padLeft(2, '0')}', style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }
}
