import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/dashboard_summary.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart' show DashboardDataSource;

class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardDataSource dataSource;
  DashboardRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, DashboardSummary>> getSummary(String studentId) async {
    try {
      return Right(await dataSource.getSummary(studentId));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
