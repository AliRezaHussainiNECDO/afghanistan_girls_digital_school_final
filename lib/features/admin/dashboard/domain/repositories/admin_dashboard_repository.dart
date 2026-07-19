import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/admin_stats.dart';

abstract class AdminDashboardRepository {
  Future<Either<Failure, AdminStats>> getStats();

  /// «نبض زندهٔ مکتب» — اعداد زندهٔ صفحهٔ اول مدیر (آنلاین/نقش‌ها/امروز).
  Future<Either<Failure, AdminLiveStats>> getLiveStats();
}
