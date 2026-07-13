import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/student_entities.dart';
import '../repositories/student_management_repository.dart';

class UpdateStatusParams {
  final String studentId;
  final AccountStatus status;
  final String reason; // برای audit_logs — اصل Auditability بخش ۱.۲
  const UpdateStatusParams({
    required this.studentId,
    required this.status,
    required this.reason,
  });
}

class UpdateStudentStatusUseCase implements UseCase<void, UpdateStatusParams> {
  final StudentManagementRepository repository;
  const UpdateStudentStatusUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(UpdateStatusParams params) =>
      repository.updateStatus(params.studentId, params.status, params.reason);
}
