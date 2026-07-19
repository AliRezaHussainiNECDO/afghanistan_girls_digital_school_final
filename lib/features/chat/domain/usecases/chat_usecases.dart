import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import 'package:equatable/equatable.dart';
import '../entities/chat_entities.dart';
import '../repositories/chat_repository.dart';

// ---------------------------------------------------------------------------
// دید شاگرد
// ---------------------------------------------------------------------------

class GetConversationsUseCase implements UseCase<List<PeerConversation>, NoParams> {
  final ChatRepository repository;
  GetConversationsUseCase(this.repository);
  @override
  Future<Either<Failure, List<PeerConversation>>> call(NoParams params) =>
      repository.getConversations();
}

/// فهرست هم‌صنفی‌های شاگرد — برای «شروع گفتگوی جدید» (بخش ۱۰.۱الف: چت
/// دو نفره فقط بین هم‌صنفی‌ها).
class GetClassmatesUseCase implements UseCase<List<Classmate>, NoParams> {
  final ChatRepository repository;
  GetClassmatesUseCase(this.repository);
  @override
  Future<Either<Failure, List<Classmate>>> call(NoParams params) => repository.getClassmates();
}

/// شروع (یا بازیابی) گفتگوی دو نفره با یک هم‌صنفی — شناسهٔ گفتگو را برمی‌گرداند.
class StartConversationUseCase implements UseCase<String, String> {
  final ChatRepository repository;
  StartConversationUseCase(this.repository);
  @override
  Future<Either<Failure, String>> call(String classmateId) =>
      repository.startConversation(classmateId);
}

class GetMessagesUseCase implements UseCase<List<PeerMessage>, String> {
  final ChatRepository repository;
  GetMessagesUseCase(this.repository);
  @override
  Future<Either<Failure, List<PeerMessage>>> call(String conversationId) =>
      repository.getMessages(conversationId);
}

class SendPeerMessageParams extends Equatable {
  final String conversationId;
  final String text;

  /// شناسهٔ پیامِ نقل‌شده — «ریپلای» (اختیاری).
  final String? replyToId;
  const SendPeerMessageParams({required this.conversationId, required this.text, this.replyToId});
  @override
  List<Object?> get props => [conversationId, text, replyToId];
}

class SendPeerMessageUseCase implements UseCase<Unit, SendPeerMessageParams> {
  final ChatRepository repository;
  SendPeerMessageUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SendPeerMessageParams params) =>
      repository.sendMessage(params.conversationId, params.text, replyToId: params.replyToId);
}

class SendVoiceMessageParams extends Equatable {
  final String conversationId;
  final String audioUrl;
  final int durationMs;
  const SendVoiceMessageParams(
      {required this.conversationId, required this.audioUrl, required this.durationMs});
  @override
  List<Object?> get props => [conversationId, audioUrl, durationMs];
}

class SendVoiceMessageUseCase implements UseCase<Unit, SendVoiceMessageParams> {
  final ChatRepository repository;
  SendVoiceMessageUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SendVoiceMessageParams params) =>
      repository.sendVoiceMessage(params.conversationId, params.audioUrl, params.durationMs);
}

class ReportMessageParams extends Equatable {
  final String messageId;
  final String reason;
  const ReportMessageParams({required this.messageId, required this.reason});
  @override
  List<Object?> get props => [messageId, reason];
}

/// گزارش‌کردن پیام مشکوک/آزاردهنده — طبق بند ۳ قوانین و شرایط استفاده
/// («هرگونه پیام مشکوک باید از طریق دکمهٔ گزارش تخلف گزارش شود»).
class ReportMessageUseCase implements UseCase<Unit, ReportMessageParams> {
  final ChatRepository repository;
  ReportMessageUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(ReportMessageParams params) =>
      repository.reportMessage(params.messageId, params.reason);
}

// ---------------------------------------------------------------------------
// دید مدیر — نظارت صنف‌به‌صنف (بخش ۱۰.۴ سند)
// ---------------------------------------------------------------------------

class GetClassChatSummariesUseCase implements UseCase<List<ClassChatSummary>, NoParams> {
  final ChatRepository repository;
  GetClassChatSummariesUseCase(this.repository);
  @override
  Future<Either<Failure, List<ClassChatSummary>>> call(NoParams params) =>
      repository.getClassChatSummaries();
}

class GetClassConversationsUseCase
    implements UseCase<List<AdminConversationSummary>, String> {
  final ChatRepository repository;
  GetClassConversationsUseCase(this.repository);
  @override
  Future<Either<Failure, List<AdminConversationSummary>>> call(String classId) =>
      repository.getClassConversations(classId);
}

/// صندوق پیام مدیریت — همهٔ گفتگوهای «شاگرد ↔ مدیریت» با هویت واقعی شاگرد.
class GetAdminInboxUseCase implements UseCase<List<AdminConversationSummary>, NoParams> {
  final ChatRepository repository;
  GetAdminInboxUseCase(this.repository);
  @override
  Future<Either<Failure, List<AdminConversationSummary>>> call(NoParams params) =>
      repository.getAdminInbox();
}

/// مشخصات یک گفتگو (عنوان، صنف، شمار پیام‌ها) برای هدر صفحهٔ نظارتی مدیر.
class GetAdminConversationInfoUseCase implements UseCase<AdminConversationSummary, String> {
  final ChatRepository repository;
  GetAdminConversationInfoUseCase(this.repository);
  @override
  Future<Either<Failure, AdminConversationSummary>> call(String conversationId) =>
      repository.getConversationInfo(conversationId);
}

class GetAdminMessagesUseCase implements UseCase<List<PeerMessage>, String> {
  final ChatRepository repository;
  GetAdminMessagesUseCase(this.repository);
  @override
  Future<Either<Failure, List<PeerMessage>>> call(String conversationId) =>
      repository.getMessagesForAdmin(conversationId);
}

class ReviewMessageParams extends Equatable {
  final String conversationId;
  final String messageId;
  final bool approve;
  const ReviewMessageParams(
      {required this.conversationId, required this.messageId, required this.approve});
  @override
  List<Object?> get props => [conversationId, messageId, approve];
}

/// تصمیم مدیر دربارهٔ پیام flag‌شده: تأیید (تحویل به گیرنده) یا رد.
class ReviewMessageUseCase implements UseCase<Unit, ReviewMessageParams> {
  final ChatRepository repository;
  ReviewMessageUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(ReviewMessageParams params) =>
      repository.reviewMessage(params.conversationId, params.messageId, params.approve);
}

class SendAdminReplyParams extends Equatable {
  final String conversationId;
  final String text;

  /// شناسهٔ پیامِ نقل‌شده — «ریپلای» مدیر به یک پیام مشخص (اختیاری).
  final String? replyToId;
  const SendAdminReplyParams({required this.conversationId, required this.text, this.replyToId});
  @override
  List<Object?> get props => [conversationId, text, replyToId];
}

class SendAdminReplyUseCase implements UseCase<Unit, SendAdminReplyParams> {
  final ChatRepository repository;
  SendAdminReplyUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SendAdminReplyParams params) =>
      repository.sendAdminReply(params.conversationId, params.text, replyToId: params.replyToId);
}
