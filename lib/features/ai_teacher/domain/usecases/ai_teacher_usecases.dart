import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import 'package:equatable/equatable.dart';
import '../entities/chat_message.dart';
import '../repositories/ai_teacher_repository.dart';

class GetConversationUseCase implements UseCase<List<AiChatMessage>, String> {
  final AiTeacherRepository repository;
  GetConversationUseCase(this.repository);
  @override
  Future<Either<Failure, List<AiChatMessage>>> call(String subjectId) =>
      repository.getConversation(subjectId);
}

class SendMessageParams extends Equatable {
  final String subjectId;
  final String text;
  const SendMessageParams({required this.subjectId, required this.text});
  @override
  List<Object?> get props => [subjectId, text];
}

class SendMessageUseCase implements UseCase<AiChatMessage, SendMessageParams> {
  final AiTeacherRepository repository;
  SendMessageUseCase(this.repository);
  @override
  Future<Either<Failure, AiChatMessage>> call(SendMessageParams params) =>
      repository.sendMessage(params.subjectId, params.text);
}
