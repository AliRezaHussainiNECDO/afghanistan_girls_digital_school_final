import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/admin_manager.dart';

abstract class AdminManagementRepository {
  Future<Either<Failure, List<AdminManager>>> getAdmins();

  Future<Either<Failure, AdminManager>> createAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required List<String> permissions,
  });

  Future<Either<Failure, List<String>>> updatePermissions(String adminId, List<String> permissions);

  Future<Either<Failure, Unit>> toggleSuspend(String adminId);
}
