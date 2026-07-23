import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/safety_queue_item.dart';
import '../../domain/repositories/safety_queue_repository.dart';
import '../datasources/safety_queue_remote_datasource.dart' show SafetyQueueDataSource;

class SafetyQueueRepositoryImpl implements SafetyQueueRepository {
  final SafetyQueueDataSource dataSource;
  SafetyQueueRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<SafetyQueueItem>>> getQueue() async {
    try {
      return Right(await dataSource.getQueue());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> resolve(String id, SafetyItemStatus newStatus) async {
    try {
      await dataSource.resolve(id, newStatus);
      return const Right(unit);
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
