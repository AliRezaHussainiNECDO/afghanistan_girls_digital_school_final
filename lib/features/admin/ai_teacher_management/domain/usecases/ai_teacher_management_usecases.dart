import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import 'package:equatable/equatable.dart';
import '../entities/ai_teacher_config.dart';
import '../entities/ai_teacher_stats.dart';
import '../repositories/ai_teacher_management_repository.dart';

class GetAiTeacherConfigsUseCase implements UseCase<List<AiTeacherConfig>, NoParams> {
  final AiTeacherManagementRepository repository;
  GetAiTeacherConfigsUseCase(this.repository);
  @override
  Future<Either<Failure, List<AiTeacherConfig>>> call(NoParams params) => repository.getConfigs();
}

class GetAiTeacherStatsUseCase implements UseCase<AiTeacherStats, NoParams> {
  final AiTeacherManagementRepository repository;
  GetAiTeacherStatsUseCase(this.repository);
  @override
  Future<Either<Failure, AiTeacherStats>> call(NoParams params) => repository.getStats();
}

class UpdatePersonaParams extends Equatable {
  final String subjectId;
  final String newDescription;
  const UpdatePersonaParams({required this.subjectId, required this.newDescription});
  @override
  List<Object?> get props => [subjectId, newDescription];
}

class UpdatePersonaUseCase implements UseCase<Unit, UpdatePersonaParams> {
  final AiTeacherManagementRepository repository;
  UpdatePersonaUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(UpdatePersonaParams params) =>
      repository.updatePersona(params.subjectId, params.newDescription);
}
