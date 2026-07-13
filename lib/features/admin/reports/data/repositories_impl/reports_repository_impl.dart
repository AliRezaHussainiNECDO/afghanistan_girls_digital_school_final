import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
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
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
