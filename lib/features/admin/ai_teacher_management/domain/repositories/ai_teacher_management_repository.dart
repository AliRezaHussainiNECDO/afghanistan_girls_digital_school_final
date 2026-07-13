import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/ai_teacher_config.dart';

abstract class AiTeacherManagementRepository {
  Future<Either<Failure, List<AiTeacherConfig>>> getConfigs();
  Future<Either<Failure, Unit>> updatePersona(String subjectId, String newDescription);
}
