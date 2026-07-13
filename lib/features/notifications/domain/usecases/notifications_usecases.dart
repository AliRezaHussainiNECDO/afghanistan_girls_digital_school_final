import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../shared_models/app_notification.dart';
import '../repositories/notifications_repository.dart';

class GetNotificationsUseCase implements UseCase<List<AppNotification>, NoParams> {
  final NotificationsRepository repository;
  GetNotificationsUseCase(this.repository);
  @override
  Future<Either<Failure, List<AppNotification>>> call(NoParams params) => repository.getAll();
}

class MarkNotificationReadUseCase implements UseCase<Unit, String> {
  final NotificationsRepository repository;
  MarkNotificationReadUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.markRead(id);
}
