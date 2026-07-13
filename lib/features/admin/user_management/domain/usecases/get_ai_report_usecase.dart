import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import 'package:dartz/dartz.dart';
import '../entities/student_entities.dart';
import '../repositories/student_management_repository.dart';

class GetAiReportUseCase implements UseCase<AiTeacherReport, String> {
  final StudentManagementRepository repository;
  const GetAiReportUseCase(this.repository);

  @override
  Future<Either<Failure, AiTeacherReport>> call(String studentId) =>
      repository.getAiReport(studentId);
}
