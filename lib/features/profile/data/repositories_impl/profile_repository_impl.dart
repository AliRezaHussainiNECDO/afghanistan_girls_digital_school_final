import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart' show ProfileDataSource;

class ProfileRepositoryImpl implements ProfileRepository {
  final ProfileDataSource dataSource;
  ProfileRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, GuardianInviteCode>> generateGuardianInviteCode(
      GuardianInviteParams params) async {
    try {
      return Right(await dataSource.generateGuardianInviteCode(params));
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
