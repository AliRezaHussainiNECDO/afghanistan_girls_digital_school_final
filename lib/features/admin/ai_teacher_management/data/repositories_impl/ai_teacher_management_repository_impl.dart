import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/ai_teacher_config.dart';
import '../../domain/entities/ai_teacher_stats.dart';
import '../../domain/repositories/ai_teacher_management_repository.dart';
import '../datasources/ai_teacher_management_data_source.dart';

class AiTeacherManagementRepositoryImpl implements AiTeacherManagementRepository {
  final AiTeacherManagementDataSource dataSource;
  AiTeacherManagementRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<AiTeacherConfig>>> getConfigs() async {
    try {
      return Right(await dataSource.getConfigs());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updatePersona(String subjectId, String newDescription) async {
    try {
      await dataSource.updatePersona(subjectId, newDescription);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String?>> getPersonaFor(String subjectId) async {
    try {
      return Right(await dataSource.personaFor(subjectId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AiTeacherStats>> getStats() async {
    try {
      return Right(await dataSource.getStats());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
