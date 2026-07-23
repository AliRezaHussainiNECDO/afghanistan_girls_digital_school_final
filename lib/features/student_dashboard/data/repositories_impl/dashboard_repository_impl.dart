import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
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
