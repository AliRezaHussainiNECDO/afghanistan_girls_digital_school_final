import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../domain/entities/homework.dart';
import '../../domain/usecases/homework_usecases.dart';
import '../providers/homework_providers.dart';

/// شیت گفتگوی «شاگرد ↔ معلم هوشمند» دربارهٔ نمرهٔ یک مشق مشخص — شاگرد بعد از
/// گرفتن نمره می‌تواند دربارهٔ بازخورد سؤال بپرسد (هماهنگ با
/// `POST /homework/:id/reply` در بک‌اند). طراحی مشابه `AiVoiceAskSheet` است تا
/// حس گفتگو با معلم هوشمند در کل اپ یکسان بماند.
Future<void> showHomeworkChatThreadView(BuildContext context, Homework homework) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: const Color(0xFF16130F),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
    ),
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: HomeworkChatThreadView(homework: homework),
    ),
  );
}

class HomeworkChatThreadView extends ConsumerStatefulWidget {
  final Homework homework;
  const HomeworkChatThreadView({super.key, required this.homework});

  @override
  ConsumerState<HomeworkChatThreadView> createState() => _HomeworkChatThreadViewState();
}

class _HomeworkChatThreadViewState extends ConsumerState<HomeworkChatThreadView> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  /// به‌روزرسانی زنده — هماهنگ با سایر چت‌های اپ: تا وقتی این گفتگو باز است،
  /// پاسخ تازه (مثلاً بازبینی مدیر/معلم) همان لحظه دیده می‌شود.
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      ref.invalidate(homeworkRepliesProvider(widget.homework.id));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty || _sending) return;
    setState(() => _sending = true);
    final result = await ref.read(sendHomeworkReplyUseCaseProvider).call(
          SendHomeworkReplyParams(homeworkId: widget.homework.id, text: t),
        );
    if (!mounted) return;
    result.fold(
      (f) => _snack(f.message),
      (_) {
        // یک منبع حقیقت واحد: Provider را باطل می‌کنیم تا از سرور تازه بخواند
        // (به‌جای نگه‌داشتن دستیِ دو کپی از تاریخچهٔ گفتگو).
        ref.invalidate(homeworkRepliesProvider(widget.homework.id));
      },
    );
    setState(() => _sending = false);
    await Future.delayed(const Duration(milliseconds: 120));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repliesAsync = ref.watch(homeworkRepliesProvider(widget.homework.id));
    final hw = widget.homework;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
                  child: const Icon(Icons.smart_toy_rounded, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.tr('homework.chatTitle'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                      Text(
                        '${hw.subjectNameFa} • ${hw.aiScore ?? '—'}/100',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: Colors.white60),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: repliesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppColors.gold500, strokeWidth: 2.5),
              ),
              error: (e, st) => ErrorView(error: e),
              data: (replies) {
                // اولین پیام همیشه بازخورد اصلی نمره است — حتی قبل از هر
                // سؤال شاگرد، تا گفتگو خالی/گنگ شروع نشود.
                return ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  children: [
                    _FeedbackBubble(homework: hw),
                    const SizedBox(height: 6),
                    for (final r in replies) ...[
                      _ChatBubble(reply: r),
                      const SizedBox(height: 8),
                    ],
                    if (_sending)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Text(context.tr('homework.aiThinking'),
                              style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: context.tr('homework.askAboutGradeHint'),
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) {
                        final t = _controller.text;
                        _controller.clear();
                        _send(t);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    decoration: const BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sending
                          ? null
                          : () {
                              final t = _controller.text;
                              _controller.clear();
                              _send(t);
                            },
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

class _FeedbackBubble extends StatelessWidget {
  final Homework homework;
  const _FeedbackBubble({required this.homework});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(color: AppColors.gold500.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.grade_rounded, size: 16, color: AppColors.gold500),
                const SizedBox(width: 6),
                Text(context.tr('homework.scoreLabel', {'score': '${homework.aiScore ?? 0}'}),
                    style: const TextStyle(color: AppColors.gold500, fontWeight: FontWeight.w800, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              homework.aiFeedback.isNotEmpty
                  ? homework.aiFeedback
                  : context.tr('homework.noFeedbackYet'),
              style: const TextStyle(color: Colors.white, height: 1.6, fontSize: 13.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final HomeworkReply reply;
  const _ChatBubble({required this.reply});

  @override
  Widget build(BuildContext context) {
    final isAi = reply.sender == HomeworkReplySender.ai;
    return Row(
      mainAxisAlignment: isAi ? MainAxisAlignment.start : MainAxisAlignment.end,
      children: [
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              gradient: isAi ? null : AppColors.heroGradient,
              color: isAi ? Colors.white.withValues(alpha: 0.06) : null,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Text(reply.text, style: const TextStyle(color: Colors.white, height: 1.5)),
          ),
        ),
      ],
    );
  }
}
