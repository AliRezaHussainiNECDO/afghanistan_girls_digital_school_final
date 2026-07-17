import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../repositories/student_management_repository.dart';

/// ارتقای دستی صنف — تصمیم مدیریتی، مستقل از شرط تکمیل خودکار (بخش ۱۵.۲).
/// خروجی: صنف جدید (سرور محاسبه/اعمال می‌کند — کلاینت فقط نمایش می‌دهد).
class PromoteStudentUseCase implements UseCase<int, String> {
  final StudentManagementRepository repository;
  const PromoteStudentUseCase(this.repository);

  @override
  Future<Either<Failure, int>> call(String studentId) =>
      repository.promoteStudent(studentId);
}

/// کاهش دستی صنف — تصمیم مدیریتی.
class DemoteStudentUseCase implements UseCase<int, String> {
  final StudentManagementRepository repository;
  const DemoteStudentUseCase(this.repository);

  @override
  Future<Either<Failure, int>> call(String studentId) =>
      repository.demoteStudent(studentId);
}
