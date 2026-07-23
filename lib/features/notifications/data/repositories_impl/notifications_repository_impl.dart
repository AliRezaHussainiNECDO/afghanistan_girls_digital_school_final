import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
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
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> markRead(String id) async {
    try {
      await dataSource.markRead(id);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}
