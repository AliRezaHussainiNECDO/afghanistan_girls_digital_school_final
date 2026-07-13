import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared_models/app_notification.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_datasource.dart' show NotificationsDataSource;

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsDataSource dataSource;
  NotificationsRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<AppNotification>>> getAll() async {
    try {
      return Right(await dataSource.getAll());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> markRead(String id) async {
    try {
      await dataSource.markRead(id);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
