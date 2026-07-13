import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/student_management_repository.dart';

class SoftDeleteParams {
  final String studentId;
  final String reason;
  const SoftDeleteParams({required this.studentId, required this.reason});
}

class SoftDeleteStudentUseCase implements UseCase<void, SoftDeleteParams> {
  final StudentManagementRepository repository;
  const SoftDeleteStudentUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(SoftDeleteParams params) =>
      repository.softDelete(params.studentId, params.reason);
}
