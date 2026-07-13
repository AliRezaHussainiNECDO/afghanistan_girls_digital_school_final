import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import 'package:dartz/dartz.dart';
import '../repositories/student_management_repository.dart';

class SendPasswordResetUseCase implements UseCase<void, String> {
  final StudentManagementRepository repository;
  const SendPasswordResetUseCase(this.repository);

  @override
  Future<Either<Failure, void>> call(String studentId) =>
      repository.sendPasswordResetLink(studentId);
}
