import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
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
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleSuspend(String userId) async {
    try {
      await dataSource.toggleSuspend(userId);
      return const Right(unit);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
