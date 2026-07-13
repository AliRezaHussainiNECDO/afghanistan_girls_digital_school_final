import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/admin_stats.dart';

abstract class AdminDashboardRepository {
  Future<Either<Failure, AdminStats>> getStats();
}
