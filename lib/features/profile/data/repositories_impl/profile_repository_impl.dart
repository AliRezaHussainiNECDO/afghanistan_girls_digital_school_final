import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/student/guardian_link_store.dart';
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
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
