import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/repositories/ai_teacher_repository.dart';
import '../datasources/ai_teacher_engine_datasource.dart';

class AiTeacherRepositoryImpl implements AiTeacherRepository {
  final AiTeacherEngineDataSource dataSource;
  AiTeacherRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<AiChatMessage>>> getConversation(String subjectId, int grade) async {
    try {
      return Right(await dataSource.getConversation(subjectId, grade));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AiChatMessage>> sendMessage(String subjectId, String text, int grade) async {
    try {
      return Right(await dataSource.sendMessage(subjectId, text, grade));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
