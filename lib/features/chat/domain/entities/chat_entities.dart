import 'package:equatable/equatable.dart';

/// طبق بخش ۱۰.۱(الف) و ۱۷.۶ سند: چت انسانی peer-to-peer، فقط بین هم‌صنفی‌ها
/// یا با مدیریت مکتب — با فیلتر سرور-ساید (اینجا شبیه‌سازی‌شده محلی تا
/// اتصال بک‌اند واقعی) و نظارت کامل مدیر بر چت‌های هر صنف.

/// یک هم‌صنفی — عضو صنفِ شاگردِ واردشده که می‌توان با او گفتگو آغاز کرد.
class Classmate extends Equatable {
  final String id;
  final String name;
  final String classId;
  final String className;
  final String? avatarUrl; // عکس پروفایل هم‌صنفی (سرور R2) — null = بدون عکس

  const Classmate({
    required this.id,
    required this.name,
    required this.classId,
    required this.className,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [id, avatarUrl];
}

/// گفتگو از دید شاگردِ واردشده — دو نفره با یک هم‌صنفی، یا با مدیریت مکتب.
class PeerConversation extends Equatable {
  final String id;
  final String peerId;
  final String peerName;
  final String peerClassName;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;
  final bool isAdmin;

  const PeerConversation({
    required this.id,
    required this.peerId,
    required this.peerName,
    this.peerClassName = '',
    required this.lastMessage,
    required this.lastMessageAt,
    this.unreadCount = 0,
    this.isAdmin = false,
  });

  @override
  List<Object?> get props => [id, lastMessage, lastMessageAt, unreadCount];
}

enum MessageKind { text, voice }

/// وضعیت بازبینی پیام flag‌شده — بخش ۱۰.۱(الف): پیام flag‌شده تا تأیید
/// Admin به گیرنده نمی‌رسد.
enum MessageReviewStatus { none, pending, approved, rejected }

class PeerMessage extends Equatable {
  final String id;

  /// هویت واقعی فرستنده — برای نمایش به مدیر (و نام فرستنده در گفتگو).
  final String senderId;
  final String senderName;
  final String senderClassName;

  /// آیا این پیام را کاربرِ فعلی فرستاده؟ (در لحظهٔ خواندن محاسبه می‌شود؛
  /// در دیتابیس ذخیره نمی‌شود چون برای هر بیننده متفاوت است.)
  final bool fromMe;

  final String body; // متن پیام، یا خالی برای پیام صوتی
  final DateTime timestamp;
  final bool flagged;
  final MessageReviewStatus reviewStatus;
  final MessageKind kind;
  final String? audioUrl; // مسیر/آدرس فایل صوتی برای پخش
  final int? durationMs;

  /// «ریپلای» (migration 0031): شناسهٔ پیامی از همین گفتگو که این پیام در
  /// پاسخ به آن فرستاده شده — کلاینت پیش‌نمایش نقل‌قول را از روی همین شناسه
  /// (در فهرست همان گفتگو) نمایش می‌دهد. null یعنی پیام عادی.
  final String? replyToId;

  const PeerMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderClassName = '',
    this.fromMe = false,
    required this.body,
    required this.timestamp,
    this.flagged = false,
    this.reviewStatus = MessageReviewStatus.none,
    this.kind = MessageKind.text,
    this.audioUrl,
    this.durationMs,
    this.replyToId,
  });

  /// آیا پیام هنوز در انتظار بازبینی مدیر است و نباید به گیرنده برسد؟
  bool get isPendingReview => flagged && reviewStatus == MessageReviewStatus.pending;

  /// آیا مدیر پیام را رد کرده است؟
  bool get isRejected => flagged && reviewStatus == MessageReviewStatus.rejected;

  @override
  List<Object?> get props => [id, reviewStatus];
}

// ---------------------------------------------------------------------------
// نمای مدیر — نظارت صنف‌به‌صنف (بخش ۱۰.۴ سند)
// ---------------------------------------------------------------------------

/// خلاصهٔ چت‌های یک صنف برای داشبورد نظارتی مدیر.
class ClassChatSummary extends Equatable {
  final String classId;
  final String className;
  final int studentCount;
  final int conversationCount;
  final int messageCount;
  final int flaggedPendingCount;
  final DateTime? lastActivityAt;

  const ClassChatSummary({
    required this.classId,
    required this.className,
    required this.studentCount,
    required this.conversationCount,
    required this.messageCount,
    required this.flaggedPendingCount,
    this.lastActivityAt,
  });

  @override
  List<Object?> get props => [classId, messageCount, flaggedPendingCount];
}

/// یک گفتگو از دید مدیر — با هویت واقعی هر دو طرف.
class AdminConversationSummary extends Equatable {
  final String id;
  final String classId;
  final String className;

  /// «فاطمه رضایی ↔ مریم احمدی» یا نام شاگرد برای گفتگو با مدیریت.
  final String title;
  final List<String> participantNames;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int messageCount;
  final int flaggedPendingCount;

  /// آیا این گفتگوی «شاگرد ↔ مدیریت» است؟ (مدیر می‌تواند پاسخ دهد.)
  final bool isAdminSupport;

  const AdminConversationSummary({
    required this.id,
    required this.classId,
    required this.className,
    required this.title,
    required this.participantNames,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.messageCount,
    required this.flaggedPendingCount,
    this.isAdminSupport = false,
  });

  @override
  List<Object?> get props => [id, lastMessage, lastMessageAt, flaggedPendingCount];
}
