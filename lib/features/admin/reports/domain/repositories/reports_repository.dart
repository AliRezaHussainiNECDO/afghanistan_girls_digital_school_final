import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/report_row.dart';

abstract class ReportsRepository {
  Future<Either<Failure, List<ReportRow>>> getSummaryReport();
}
