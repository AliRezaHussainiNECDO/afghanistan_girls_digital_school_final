import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/final_exam_entities.dart';
import '../repositories/admin_final_exam_repository.dart';

class GetAdminFinalExamsParams extends Equatable {
  final int? gradeNumber;
  const GetAdminFinalExamsParams({this.gradeNumber});
  @override
  List<Object?> get props => [gradeNumber];
}

class GetAdminFinalExamsUseCase implements UseCase<List<AdminFinalExamRow>, GetAdminFinalExamsParams> {
  final AdminFinalExamRepository repository;
  GetAdminFinalExamsUseCase(this.repository);
  @override
  Future<Either<Failure, List<AdminFinalExamRow>>> call(GetAdminFinalExamsParams params) =>
      repository.getFinalExams(gradeNumber: params.gradeNumber);
}

class CreateFinalExamParams extends Equatable {
  final int gradeNumber;
  final String academicYear;
  final String title;
  const CreateFinalExamParams({required this.gradeNumber, required this.academicYear, required this.title});
  @override
  List<Object?> get props => [gradeNumber, academicYear, title];
}

class CreateFinalExamUseCase implements UseCase<AdminFinalExamRow, CreateFinalExamParams> {
  final AdminFinalExamRepository repository;
  CreateFinalExamUseCase(this.repository);
  @override
  Future<Either<Failure, AdminFinalExamRow>> call(CreateFinalExamParams params) =>
      repository.createFinalExam(gradeNumber: params.gradeNumber, academicYear: params.academicYear, title: params.title);
}

class SetFinalExamStatusParams extends Equatable {
  final String id;
  final FinalExamAdminStatus status;
  const SetFinalExamStatusParams({required this.id, required this.status});
  @override
  List<Object?> get props => [id, status];
}

class SetFinalExamStatusUseCase implements UseCase<Unit, SetFinalExamStatusParams> {
  final AdminFinalExamRepository repository;
  SetFinalExamStatusUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SetFinalExamStatusParams params) => repository.setStatus(params.id, params.status);
}

class DeleteFinalExamUseCase implements UseCase<Unit, String> {
  final AdminFinalExamRepository repository;
  DeleteFinalExamUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.deleteFinalExam(id);
}

class GetAdminFinalExamQuestionsUseCase implements UseCase<List<AdminFinalExamQuestionRow>, String> {
  final AdminFinalExamRepository repository;
  GetAdminFinalExamQuestionsUseCase(this.repository);
  @override
  Future<Either<Failure, List<AdminFinalExamQuestionRow>>> call(String finalExamId) => repository.getQuestions(finalExamId);
}

class SaveFinalExamQuestionUseCase implements UseCase<AdminFinalExamQuestionRow, AdminFinalExamQuestionRow> {
  final AdminFinalExamRepository repository;
  SaveFinalExamQuestionUseCase(this.repository);
  @override
  Future<Either<Failure, AdminFinalExamQuestionRow>> call(AdminFinalExamQuestionRow params) => repository.saveQuestion(params);
}

class DeleteFinalExamQuestionUseCase implements UseCase<Unit, String> {
  final AdminFinalExamRepository repository;
  DeleteFinalExamQuestionUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.deleteQuestion(id);
}

class GenerateFinalExamQuestionsParams extends Equatable {
  final String finalExamId;
  final int perSubjectCount;
  const GenerateFinalExamQuestionsParams({required this.finalExamId, this.perSubjectCount = 3});
  @override
  List<Object?> get props => [finalExamId, perSubjectCount];
}

class GenerateFinalExamQuestionsUseCase implements UseCase<GenerateFinalExamResult, GenerateFinalExamQuestionsParams> {
  final AdminFinalExamRepository repository;
  GenerateFinalExamQuestionsUseCase(this.repository);
  @override
  Future<Either<Failure, GenerateFinalExamResult>> call(GenerateFinalExamQuestionsParams params) =>
      repository.generateQuestions(params.finalExamId, perSubjectCount: params.perSubjectCount);
}
