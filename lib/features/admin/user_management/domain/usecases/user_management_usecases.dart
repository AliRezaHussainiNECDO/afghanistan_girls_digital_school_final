import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/admin_user_row.dart';
import '../repositories/user_management_repository.dart';

class GetUsersUseCase implements UseCase<List<AdminUserRow>, String> {
  final UserManagementRepository repository;
  GetUsersUseCase(this.repository);
  @override
  Future<Either<Failure, List<AdminUserRow>>> call(String query) => repository.getUsers(query);
}

class ToggleSuspendUseCase implements UseCase<Unit, String> {
  final UserManagementRepository repository;
  ToggleSuspendUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String userId) => repository.toggleSuspend(userId);
}
