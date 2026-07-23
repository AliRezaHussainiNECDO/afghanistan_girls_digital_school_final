import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
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
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> updatePersona(String subjectId, String newDescription) async {
    try {
      await dataSource.updatePersona(subjectId, newDescription);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, String?>> getPersonaFor(String subjectId) async {
    try {
      return Right(await dataSource.personaFor(subjectId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AiTeacherStats>> getStats() async {
    try {
      return Right(await dataSource.getStats());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}
