import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
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
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> resolve(String id, SafetyItemStatus newStatus) async {
    try {
      await dataSource.resolve(id, newStatus);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
