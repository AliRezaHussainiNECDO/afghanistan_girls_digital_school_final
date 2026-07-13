import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/student_entities.dart';

/// Interface انتزاعی — لایهٔ presentation فقط همین را می‌شناسد (بخش ۲۴.۳).
abstract class StudentManagementRepository {
  Future<Either<Failure, PagedStudents>> getStudents(StudentListFilter filter);

  Future<Either<Failure, StudentDetail>> getStudentDetail(String studentId);

  /// GET /api/v1/admin/students/{id}/ai-report
  Future<Either<Failure, AiTeacherReport>> getAiReport(String studentId);

  /// PATCH /api/v1/admin/users/{id}  body: {status: suspended|active}
  Future<Either<Failure, void>> updateStatus(
      String studentId, AccountStatus status, String reason);

  /// Soft delete (بخش ۱۵.۲) — PATCH /api/v1/admin/users/{id} {status: deleted}
  Future<Either<Failure, void>> softDelete(String studentId, String reason);

  /// ارسال لینک ریست رمز (نه نمایش مستقیم رمز — بخش ۱۵.۲)
  Future<Either<Failure, void>> sendPasswordResetLink(String studentId);
}
