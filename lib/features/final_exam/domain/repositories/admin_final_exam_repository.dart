import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/final_exam_entities.dart';

abstract class AdminFinalExamRepository {
  Future<Either<Failure, List<AdminFinalExamRow>>> getFinalExams({int? gradeNumber});
  Future<Either<Failure, AdminFinalExamRow>> createFinalExam({
    required int gradeNumber,
    required String academicYear,
    required String title,
  });
  Future<Either<Failure, Unit>> setStatus(String id, FinalExamAdminStatus status);
  Future<Either<Failure, Unit>> deleteFinalExam(String id);

  Future<Either<Failure, List<AdminFinalExamQuestionRow>>> getQuestions(String finalExamId);
  Future<Either<Failure, AdminFinalExamQuestionRow>> saveQuestion(AdminFinalExamQuestionRow row);
  Future<Either<Failure, Unit>> deleteQuestion(String id);

  /// تولید یک‌جا با AI برای همهٔ مضامین صنف — حداقل ۳ سؤال از هر مضمون.
  Future<Either<Failure, GenerateFinalExamResult>> generateQuestions(String finalExamId, {int perSubjectCount});
}
