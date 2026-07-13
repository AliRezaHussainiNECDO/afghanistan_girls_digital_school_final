import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/admin_stats.dart';
import '../../domain/repositories/admin_dashboard_repository.dart';
import '../datasources/admin_dashboard_remote_datasource.dart' show AdminDashboardDataSource;

class AdminDashboardRepositoryImpl implements AdminDashboardRepository {
  final AdminDashboardDataSource dataSource;
  AdminDashboardRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, AdminStats>> getStats() async {
    try {
      return Right(await dataSource.getStats());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
