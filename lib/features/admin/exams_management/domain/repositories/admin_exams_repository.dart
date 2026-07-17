import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/admin_exam_entities.dart';

abstract class AdminExamsRepository {
  Future<Either<Failure, List<AdminExamRow>>> getExams();
  Future<Either<Failure, AdminExamRow>> saveExam(AdminExamRow row);
  Future<Either<Failure, Unit>> setExamStatus(String id, ExamAdminStatus status);
  Future<Either<Failure, Unit>> deleteExam(String id);

  Future<Either<Failure, List<AdminQuestionRow>>> getQuestions(String examId);
  Future<Either<Failure, AdminQuestionRow>> saveQuestion(AdminQuestionRow row);
  Future<Either<Failure, Unit>> deleteQuestion(String id);
}
