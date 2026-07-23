import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/admin_user_row.dart';
import '../../domain/repositories/user_management_repository.dart';
import '../datasources/user_management_remote_datasource.dart' show UserManagementDataSource;

class UserManagementRepositoryImpl implements UserManagementRepository {
  final UserManagementDataSource dataSource;
  UserManagementRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<AdminUserRow>>> getUsers(String query) async {
    try {
      return Right(await dataSource.getUsers(query));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleSuspend(String userId) async {
    try {
      await dataSource.toggleSuspend(userId);
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
