import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repositories/profile_repository.dart';

class GenerateGuardianInviteCodeUseCase
    implements UseCase<GuardianInviteCode, GuardianInviteParams> {
  final ProfileRepository repository;
  GenerateGuardianInviteCodeUseCase(this.repository);
  @override
  Future<Either<Failure, GuardianInviteCode>> call(GuardianInviteParams params) =>
      repository.generateGuardianInviteCode(params);
}
