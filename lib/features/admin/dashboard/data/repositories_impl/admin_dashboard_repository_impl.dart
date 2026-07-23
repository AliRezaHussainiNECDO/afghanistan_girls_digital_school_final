import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
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
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AdminLiveStats>> getLiveStats() async {
    try {
      return Right(await dataSource.getLiveStats());
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
