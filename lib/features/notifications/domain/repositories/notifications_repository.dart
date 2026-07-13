import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared_models/app_notification.dart';

abstract class NotificationsRepository {
  Future<Either<Failure, List<AppNotification>>> getAll();
  Future<Either<Failure, Unit>> markRead(String id);
}
