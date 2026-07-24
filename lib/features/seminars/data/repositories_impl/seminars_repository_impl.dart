import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared_models/seminar.dart';
import '../../domain/repositories/seminars_repository.dart';
import '../datasources/seminars_remote_datasource.dart' show SeminarsDataSource;

class SeminarsRepositoryImpl implements SeminarsRepository {
  final SeminarsDataSource dataSource;
  SeminarsRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<Seminar>>> getUpcoming(SeminarAudience audience) async {
    try {
      return Right(await dataSource.getUpcoming(audience));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Seminar>> getById(String id) async {
    try {
      return Right(await dataSource.getById(id));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> register(String seminarId, String userId) async {
    try {
      await dataSource.register(seminarId, userId);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> unregister(String seminarId, String userId) async {
    try {
      await dataSource.unregister(seminarId, userId);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> setStatus(String seminarId, SeminarStatus status) async {
    try {
      await dataSource.setStatus(seminarId, status);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest
          ? ValidationFailure(e.message)
          : ServerFailure(e.message, code: e.code));
}
