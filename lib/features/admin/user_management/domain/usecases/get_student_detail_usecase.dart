import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/student_entities.dart';
import '../repositories/student_management_repository.dart';

class GetStudentDetailUseCase implements UseCase<StudentDetail, String> {
  final StudentManagementRepository repository;
  const GetStudentDetailUseCase(this.repository);

  @override
  Future<Either<Failure, StudentDetail>> call(String studentId) =>
      repository.getStudentDetail(studentId);
}
