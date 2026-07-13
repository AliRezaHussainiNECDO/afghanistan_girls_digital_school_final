import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import 'package:equatable/equatable.dart';
import '../entities/safety_queue_item.dart';
import '../repositories/safety_queue_repository.dart';

class GetSafetyQueueUseCase implements UseCase<List<SafetyQueueItem>, NoParams> {
  final SafetyQueueRepository repository;
  GetSafetyQueueUseCase(this.repository);
  @override
  Future<Either<Failure, List<SafetyQueueItem>>> call(NoParams params) => repository.getQueue();
}

class ResolveSafetyItemParams extends Equatable {
  final String id;
  final SafetyItemStatus newStatus;
  const ResolveSafetyItemParams({required this.id, required this.newStatus});
  @override
  List<Object?> get props => [id, newStatus];
}

class ResolveSafetyItemUseCase implements UseCase<Unit, ResolveSafetyItemParams> {
  final SafetyQueueRepository repository;
  ResolveSafetyItemUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(ResolveSafetyItemParams params) =>
      repository.resolve(params.id, params.newStatus);
}
