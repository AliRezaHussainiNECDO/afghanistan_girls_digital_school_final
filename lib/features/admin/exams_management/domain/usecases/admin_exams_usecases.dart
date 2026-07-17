import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/admin_exam_entities.dart';
import '../repositories/admin_exams_repository.dart';

class SetExamStatusParams extends Equatable {
  final String id;
  final ExamAdminStatus status;
  const SetExamStatusParams({required this.id, required this.status});
  @override
  List<Object?> get props => [id, status];
}

class GetAdminExamsUseCase implements UseCase<List<AdminExamRow>, NoParams> {
  final AdminExamsRepository repository;
  GetAdminExamsUseCase(this.repository);
  @override
  Future<Either<Failure, List<AdminExamRow>>> call(NoParams params) => repository.getExams();
}

class SaveExamUseCase implements UseCase<AdminExamRow, AdminExamRow> {
  final AdminExamsRepository repository;
  SaveExamUseCase(this.repository);
  @override
  Future<Either<Failure, AdminExamRow>> call(AdminExamRow params) => repository.saveExam(params);
}

class SetExamStatusUseCase implements UseCase<Unit, SetExamStatusParams> {
  final AdminExamsRepository repository;
  SetExamStatusUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SetExamStatusParams p) => repository.setExamStatus(p.id, p.status);
}

class DeleteExamUseCase implements UseCase<Unit, String> {
  final AdminExamsRepository repository;
  DeleteExamUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.deleteExam(id);
}

class GetAdminQuestionsUseCase implements UseCase<List<AdminQuestionRow>, String> {
  final AdminExamsRepository repository;
  GetAdminQuestionsUseCase(this.repository);
  @override
  Future<Either<Failure, List<AdminQuestionRow>>> call(String examId) => repository.getQuestions(examId);
}

class SaveQuestionUseCase implements UseCase<AdminQuestionRow, AdminQuestionRow> {
  final AdminExamsRepository repository;
  SaveQuestionUseCase(this.repository);
  @override
  Future<Either<Failure, AdminQuestionRow>> call(AdminQuestionRow params) => repository.saveQuestion(params);
}

class DeleteQuestionUseCase implements UseCase<Unit, String> {
  final AdminExamsRepository repository;
  DeleteQuestionUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.deleteQuestion(id);
}
