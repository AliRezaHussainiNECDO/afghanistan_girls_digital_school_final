import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import 'package:equatable/equatable.dart';
import '../entities/chat_message.dart';
import '../repositories/ai_teacher_repository.dart';

class GetConversationParams extends Equatable {
  final String subjectId;
  final int grade;
  const GetConversationParams({required this.subjectId, required this.grade});
  @override
  List<Object?> get props => [subjectId, grade];
}

class GetConversationUseCase implements UseCase<List<AiChatMessage>, GetConversationParams> {
  final AiTeacherRepository repository;
  GetConversationUseCase(this.repository);
  @override
  Future<Either<Failure, List<AiChatMessage>>> call(GetConversationParams params) =>
      repository.getConversation(params.subjectId, params.grade);
}

class SendMessageParams extends Equatable {
  final String subjectId;
  final String text;
  final int grade;
  const SendMessageParams({required this.subjectId, required this.text, required this.grade});
  @override
  List<Object?> get props => [subjectId, text, grade];
}

class SendMessageUseCase implements UseCase<AiChatMessage, SendMessageParams> {
  final AiTeacherRepository repository;
  SendMessageUseCase(this.repository);
  @override
  Future<Either<Failure, AiChatMessage>> call(SendMessageParams params) =>
      repository.sendMessage(params.subjectId, params.text, params.grade);
}
