import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/admin_stats.dart';
import '../repositories/admin_dashboard_repository.dart';

class GetAdminStatsUseCase implements UseCase<AdminStats, NoParams> {
  final AdminDashboardRepository repository;
  GetAdminStatsUseCase(this.repository);
  @override
  Future<Either<Failure, AdminStats>> call(NoParams params) => repository.getStats();
}

/// «نبض زندهٔ مکتب» — آمار زندهٔ صفحهٔ اول مدیر (هر چند ثانیه تازه می‌شود).
class GetAdminLiveStatsUseCase implements UseCase<AdminLiveStats, NoParams> {
  final AdminDashboardRepository repository;
  GetAdminLiveStatsUseCase(this.repository);
  @override
  Future<Either<Failure, AdminLiveStats>> call(NoParams params) => repository.getLiveStats();
}
