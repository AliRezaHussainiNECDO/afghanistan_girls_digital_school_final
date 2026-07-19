import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/chat_entities.dart';

/// ابزارهای مشترک UI چت — آواتار گرادیانی، زمان نسبی و جداکنندهٔ تاریخ.
/// هم در صفحات شاگرد و هم در صفحات نظارتی مدیر استفاده می‌شوند تا زبان
/// طراحی چت در سراسر اپ یکسان بماند.

const List<Gradient> _avatarGradients = [
  AppColors.heroGradient,
  AppColors.successGradient,
  AppColors.heroGradientWarm,
  LinearGradient(colors: [AppColors.info, Color(0xFF2B65A0)]),
  LinearGradient(colors: [AppColors.gold500, AppColors.orange500]),
];

/// گرادیان پایدار بر اساس نام — هر شاگرد همیشه یک رنگ ثابت دارد.
Gradient avatarGradientFor(String name) =>
    _avatarGradients[name.codeUnits.fold<int>(0, (a, b) => a + b) % _avatarGradients.length];

class ChatAvatar extends StatelessWidget {
  final String name;
  final bool isAdmin;
  final double size;

  /// عکس پروفایل واقعی کاربر (سرور R2)؛ اگر null باشد حرف اول با گرادیان.
  final String? avatarUrl;

  const ChatAvatar({
    super.key,
    required this.name,
    this.isAdmin = false,
    this.size = 44,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    // اگر عکس پروفایل موجود است، همان نمایش داده می‌شود (در صورت خطای
    // بارگیری شبکه، خودکار به حرف اول برمی‌گردد).
    if (!isAdmin && avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.soft),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.transparent,
          foregroundImage: NetworkImage(avatarUrl!),
          onForegroundImageError: (_, __) {},
          child: _fallback(),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isAdmin ? AppColors.successGradient : avatarGradientFor(name),
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      child: Center(
        child: isAdmin
            ? Icon(Icons.shield_rounded, color: Colors.white, size: size * 0.46)
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4),
      );
}

/// زمان نسبی — طبق زبان فعال («همین حالا»، «۵ دقیقه پیش»، «دیروز»، یا تاریخ).
String relativeTimeFa(BuildContext context, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return context.tr('notifications.justNow');
  if (diff.inMinutes < 60) return context.tr('notifications.minutesAgo', {'count': '${diff.inMinutes}'});
  if (diff.inHours < 24 && time.day == DateTime.now().day) {
    return context.tr('notifications.hoursAgo', {'count': '${diff.inHours}'});
  }
  if (diff.inHours < 48) return context.tr('notifications.bucketYesterday');
  return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
}

/// برچسب جداکنندهٔ تاریخ بین پیام‌ها — «امروز»، «دیروز» یا تاریخ کامل.
String dateLabelFa(BuildContext context, DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  if (day == today) return context.tr('notifications.bucketToday');
  if (day == today.subtract(const Duration(days: 1))) return context.tr('notifications.bucketYesterday');
  return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
}

/// ساعت پیام به فرمت HH:MM.
String clockFa(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

// ═══════════════════════════ «ریپلای» — ابزار مشترک ═══════════════════════════
// طراحی مدرن و پویا، یکسان در همهٔ سطح‌های چت (هم‌صنفی‌ها، ارتباط با مدیریت
// برای هر نقش، و پاسخ مدیر از داشبورد نظارتی):
//   • SwipeToReply    کشیدن حباب پیام به پهلو (با لرزش ظریف) → حالت ریپلای
//   • ReplyComposerBar پیش‌نمایش انیمیشنی پیامِ نقل‌شده بالای نوار نوشتن
//   • QuotedMessage   نقل‌قول داخل حباب — با لمس، به پیام اصلی می‌پرد

/// متن کوتاهِ پیش‌نمایش یک پیام (برای نقل‌قول/ریپلای).
String replySnippet(BuildContext context, PeerMessage? m) {
  if (m == null) return context.tr('chat.quotedUnknown');
  if (m.kind == MessageKind.voice) return context.tr('chat.quotedVoice');
  return m.body;
}

/// کشیدن افقی حباب پیام برای ریپلای — مثل پیام‌رسان‌های مدرن: حباب همراه
/// انگشت جابه‌جا می‌شود، آیکن پاسخ به‌تدریج ظاهر می‌شود و با عبور از آستانه،
/// لرزش ظریف + فراخوانی [onReply]؛ سپس حباب با انیمیسیون فنری برمی‌گردد.
class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback? onReply;
  const SwipeToReply({super.key, required this.child, this.onReply});

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  static const _threshold = 52.0;
  double _dx = 0;
  bool _dragging = false;
  bool _fired = false;

  void _onUpdate(DragUpdateDetails d) {
    if (widget.onReply == null) return;
    setState(() {
      _dragging = true;
      _dx = (_dx + d.delta.dx).clamp(-76.0, 76.0);
    });
    if (!_fired && _dx.abs() >= _threshold) {
      _fired = true;
      HapticFeedback.mediumImpact();
    }
  }

  void _onEnd(DragEndDetails d) {
    final shouldReply = _dx.abs() >= _threshold;
    setState(() {
      _dragging = false;
      _dx = 0;
      _fired = false;
    });
    if (shouldReply) widget.onReply?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;
    final scheme = Theme.of(context).colorScheme;
    final progress = (_dx.abs() / _threshold).clamp(0.0, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _onUpdate,
      onHorizontalDragEnd: _onEnd,
      onHorizontalDragCancel: () => setState(() {
        _dragging = false;
        _dx = 0;
        _fired = false;
      }),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // آیکن پاسخ — سمتِ شروعِ کشیدن، با ظهور و بزرگ‌شدن تدریجی.
          if (progress > 0)
            Align(
              alignment: _dx > 0 ? Alignment.centerLeft : Alignment.centerRight,
              child: Opacity(
                opacity: progress,
                child: Transform.scale(
                  scale: 0.6 + 0.4 * progress,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 10),
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      shape: BoxShape.circle,
                      boxShadow: progress >= 1 ? AppShadows.soft : null,
                    ),
                    child: Icon(Icons.reply_rounded,
                        size: 18, color: scheme.onPrimaryContainer),
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

/// نوار «در پاسخ به …» بالای نوار نوشتن — با خط تأکید رنگی، نام فرستنده،
/// پیش‌نمایش پیام و دکمهٔ بستن. ظاهر/پنهان‌شدن آن را صفحهٔ میزبان با
/// AnimatedSwitcher/animate انجام می‌دهد.
class ReplyComposerBar extends StatelessWidget {
  final PeerMessage replyingTo;
  final VoidCallback onCancel;
  const ReplyComposerBar({super.key, required this.replyingTo, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsetsDirectional.only(start: 10, end: 4, top: 8, bottom: 8),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 3.5,
            height: 34,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(Icons.reply_rounded, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.tr('chat.replyingTo', {'name': replyingTo.senderName}),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w800, color: scheme.primary),
                ),
                const SizedBox(height: 2),
                Text(
                  replySnippet(context, replyingTo),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: scheme.onSurfaceVariant),
            onPressed: onCancel,
            tooltip: context.tr('common.cancel'),
          ),
        ],
      ),
    );
  }
}

/// نقل‌قولِ پیام اصلی داخل حباب ریپلای — لمس آن به پیام اصلی می‌پرد.
/// [onGradient] یعنی داخل حباب گرادیانیِ خود کاربر است (رنگ‌های روشن).
class QuotedMessage extends StatelessWidget {
  final PeerMessage? original;
  final bool onGradient;
  final VoidCallback? onTap;
  const QuotedMessage({super.key, required this.original, this.onGradient = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = onGradient ? Colors.white : scheme.primary;
    final nameColor = onGradient ? Colors.white : scheme.primary;
    final textColor =
        onGradient ? Colors.white.withValues(alpha: 0.9) : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.sm),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsetsDirectional.only(start: 8, end: 10, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: (onGradient ? Colors.white : scheme.primary).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 3,
              height: 30,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    original?.senderName.isNotEmpty == true
                        ? original!.senderName
                        : context.tr('chat.quotedUnknown'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w800, color: nameColor),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    replySnippet(context, original),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, height: 1.4, color: textColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DateSeparator extends StatelessWidget {
  final DateTime date;
  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(dateLabelFa(context, date),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}
