import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/admin_user_row.dart';

abstract class UserManagementRepository {
  Future<Either<Failure, List<AdminUserRow>>> getUsers(String query);
  Future<Either<Failure, Unit>> toggleSuspend(String userId);
}
