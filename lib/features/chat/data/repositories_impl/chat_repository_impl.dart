import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/chat_entities.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/network/api_client.dart';
import '../datasources/chat_remote_datasource.dart' show ChatDataSource;

class ChatRepositoryImpl implements ChatRepository {
  final ChatDataSource dataSource;
  ChatRepositoryImpl(this.dataSource);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } on ApiException catch (e) {
      return Left(e.isNetworkError
          ? NetworkFailure(e.message)
          : ServerFailure(e.message, code: e.code));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PeerConversation>>> getConversations() =>
      _guard(dataSource.getConversations);

  @override
  Future<Either<Failure, List<Classmate>>> getClassmates() => _guard(dataSource.getClassmates);

  @override
  Future<Either<Failure, String>> startConversation(String classmateId) =>
      _guard(() => dataSource.startConversationWith(classmateId));

  @override
  Future<Either<Failure, List<PeerMessage>>> getMessages(String conversationId) =>
      _guard(() => dataSource.getMessages(conversationId));

  @override
  Future<Either<Failure, Unit>> sendMessage(String conversationId, String text) =>
      _guard(() async {
        await dataSource.sendMessage(conversationId, text);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> sendVoiceMessage(
          String conversationId, String audioUrl, int durationMs) =>
      _guard(() async {
        await dataSource.sendVoiceMessage(conversationId, audioUrl, durationMs);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> reportMessage(String messageId, String reason) =>
      _guard(() async {
        await dataSource.reportMessage(messageId, reason);
        return unit;
      });

  @override
  Future<Either<Failure, List<ClassChatSummary>>> getClassChatSummaries() =>
      _guard(dataSource.getClassChatSummaries);

  @override
  Future<Either<Failure, List<AdminConversationSummary>>> getClassConversations(
          String classId) =>
      _guard(() => dataSource.getClassConversations(classId));

  @override
  Future<Either<Failure, List<AdminConversationSummary>>> getAdminInbox() =>
      _guard(dataSource.getAdminInbox);

  @override
  Future<Either<Failure, AdminConversationSummary>> getConversationInfo(String conversationId) =>
      _guard(() => dataSource.getConversationInfo(conversationId));

  @override
  Future<Either<Failure, List<PeerMessage>>> getMessagesForAdmin(String conversationId) =>
      _guard(() => dataSource.getMessagesForAdmin(conversationId));

  @override
  Future<Either<Failure, Unit>> reviewMessage(
          String conversationId, String messageId, bool approve) =>
      _guard(() async {
        await dataSource.reviewMessage(conversationId, messageId, approve);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> sendAdminReply(String conversationId, String text) =>
      _guard(() async {
        await dataSource.sendAdminReply(conversationId, text);
        return unit;
      });
}
