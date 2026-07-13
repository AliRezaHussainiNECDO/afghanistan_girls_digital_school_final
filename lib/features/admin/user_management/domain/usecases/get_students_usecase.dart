import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/student_entities.dart';
import '../repositories/student_management_repository.dart';

class GetStudentsUseCase implements UseCase<PagedStudents, StudentListFilter> {
  final StudentManagementRepository repository;
  const GetStudentsUseCase(this.repository);

  @override
  Future<Either<Failure, PagedStudents>> call(StudentListFilter params) =>
      repository.getStudents(params);
}
