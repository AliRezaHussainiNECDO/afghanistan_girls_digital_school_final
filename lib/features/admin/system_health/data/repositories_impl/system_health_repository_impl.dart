import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/system_health.dart';
import '../../domain/repositories/system_health_repository.dart';
import '../datasources/system_health_remote_datasource.dart' show SystemHealthDataSource;

class SystemHealthRepositoryImpl implements SystemHealthRepository {
  final SystemHealthDataSource dataSource;
  SystemHealthRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, SystemHealth>> checkHealth() async {
    try {
      return Right(await dataSource.checkHealth());
    } catch (e) {
      return Left(NetworkFailure(e.toString()));
    }
  }
}
