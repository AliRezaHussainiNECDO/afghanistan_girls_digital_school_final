import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/dashboard_summary.dart';
import '../repositories/dashboard_repository.dart';

class GetDashboardSummaryUseCase implements UseCase<DashboardSummary, String> {
  final DashboardRepository repository;
  GetDashboardSummaryUseCase(this.repository);

  @override
  Future<Either<Failure, DashboardSummary>> call(String studentId) {
    return repository.getSummary(studentId);
  }
}
