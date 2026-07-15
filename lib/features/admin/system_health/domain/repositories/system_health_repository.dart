import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/system_health.dart';

abstract class SystemHealthRepository {
  Future<Either<Failure, SystemHealth>> checkHealth();
}
