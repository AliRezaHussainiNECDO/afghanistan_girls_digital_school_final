import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/safety_queue_item.dart';

abstract class SafetyQueueRepository {
  Future<Either<Failure, List<SafetyQueueItem>>> getQueue();
  Future<Either<Failure, Unit>> resolve(String id, SafetyItemStatus newStatus);
}
