import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/chat_entities.dart';

abstract class ChatRepository {
  // --- دید شاگرد ---
  Future<Either<Failure, List<PeerConversation>>> getConversations();
  Future<Either<Failure, List<Classmate>>> getClassmates();
  Future<Either<Failure, String>> startConversation(String classmateId);
  Future<Either<Failure, List<PeerMessage>>> getMessages(String conversationId);
  /// [replyToId]: شناسهٔ پیامِ نقل‌شده — «ریپلای» (migration 0031).
  Future<Either<Failure, Unit>> sendMessage(String conversationId, String text, {String? replyToId});
  Future<Either<Failure, Unit>> sendVoiceMessage(
      String conversationId, String audioUrl, int durationMs);
  Future<Either<Failure, Unit>> reportMessage(String messageId, String reason);

  // --- دید مدیر (بخش ۱۰.۴: نظارت صنف‌به‌صنف با هویت واقعی شاگرد) ---
  Future<Either<Failure, List<ClassChatSummary>>> getClassChatSummaries();
  Future<Either<Failure, List<AdminConversationSummary>>> getClassConversations(String classId);
  Future<Either<Failure, List<AdminConversationSummary>>> getAdminInbox();
  Future<Either<Failure, AdminConversationSummary>> getConversationInfo(String conversationId);
  Future<Either<Failure, List<PeerMessage>>> getMessagesForAdmin(String conversationId);
  Future<Either<Failure, Unit>> reviewMessage(
      String conversationId, String messageId, bool approve);
  Future<Either<Failure, Unit>> sendAdminReply(String conversationId, String text, {String? replyToId});
}
