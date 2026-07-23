import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/report_row.dart';
import '../../domain/repositories/reports_repository.dart';
import '../datasources/reports_remote_datasource.dart' show ReportsDataSource;

class ReportsRepositoryImpl implements ReportsRepository {
  final ReportsDataSource dataSource;
  ReportsRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<ReportRow>>> getSummaryReport() async {
    try {
      return Right(await dataSource.getSummaryReport());
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
