import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/report_row.dart';
import '../repositories/reports_repository.dart';

class GetSummaryReportUseCase implements UseCase<List<ReportRow>, NoParams> {
  final ReportsRepository repository;
  GetSummaryReportUseCase(this.repository);
  @override
  Future<Either<Failure, List<ReportRow>>> call(NoParams params) => repository.getSummaryReport();
}
