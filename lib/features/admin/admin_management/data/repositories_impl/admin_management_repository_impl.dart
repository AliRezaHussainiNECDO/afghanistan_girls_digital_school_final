import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/admin_manager.dart';
import '../../domain/repositories/admin_management_repository.dart';
import '../datasources/admin_management_remote_datasource.dart';

class AdminManagementRepositoryImpl implements AdminManagementRepository {
  final AdminManagementRemoteDataSource dataSource;
  AdminManagementRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, List<AdminManager>>> getAdmins() async {
    try {
      return Right(await dataSource.getAdmins());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AdminManager>> createAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required List<String> permissions,
  }) async {
    try {
      return Right(await dataSource.createAdmin(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
        permissions: permissions,
      ));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> updatePermissions(String adminId, List<String> permissions) async {
    try {
      return Right(await dataSource.updatePermissions(adminId, permissions));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> toggleSuspend(String adminId) async {
    try {
      await dataSource.toggleSuspend(adminId);
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
