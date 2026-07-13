import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/chat_message.dart';

abstract class AiTeacherRepository {
  /// `grade` = صنف فعال واقعی شاگرد (از `activeGradeProvider`) — تضمین می‌کند
  /// معلم هوشمند همیشه دقیقاً از نصاب همان صنف تدریس می‌کند.
  Future<Either<Failure, List<AiChatMessage>>> getConversation(String subjectId, int grade);

  /// طبق `POST /ai-teacher/{subjectId}/chat` بخش ۱۹.۴ — ورودی RAG Pipeline بخش ۵.۳.۲.
  Future<Either<Failure, AiChatMessage>> sendMessage(String subjectId, String text, int grade);
}
