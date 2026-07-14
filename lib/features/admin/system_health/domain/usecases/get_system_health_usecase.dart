import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/system_health.dart';
import '../repositories/system_health_repository.dart';

class GetSystemHealthUseCase implements UseCase<SystemHealth, NoParams> {
  final SystemHealthRepository repository;
  GetSystemHealthUseCase(this.repository);

  @override
  Future<Either<Failure, SystemHealth>> call(NoParams params) => repository.checkHealth();
}
