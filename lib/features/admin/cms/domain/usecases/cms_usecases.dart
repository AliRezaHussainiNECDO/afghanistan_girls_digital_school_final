import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../entities/cms_entities.dart';
import '../repositories/cms_repository.dart';

/// پارامتر مشترک تغییر وضعیت محتوا.
class SetStatusParams extends Equatable {
  final String id;
  final ContentStatus status;
  const SetStatusParams({required this.id, required this.status});
  @override
  List<Object?> get props => [id, status];
}

// ─────────────────────────── BOOKS ───────────────────────────
class GetBooksUseCase implements UseCase<List<CmsBookRow>, NoParams> {
  final CmsRepository repository;
  GetBooksUseCase(this.repository);
  @override
  Future<Either<Failure, List<CmsBookRow>>> call(NoParams params) => repository.getBooks();
}

class SaveBookUseCase implements UseCase<CmsBookRow, CmsBookRow> {
  final CmsRepository repository;
  SaveBookUseCase(this.repository);
  @override
  Future<Either<Failure, CmsBookRow>> call(CmsBookRow params) => repository.saveBook(params);
}

class DeleteBookUseCase implements UseCase<Unit, String> {
  final CmsRepository repository;
  DeleteBookUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.deleteBook(id);
}

class SetBookStatusUseCase implements UseCase<Unit, SetStatusParams> {
  final CmsRepository repository;
  SetBookStatusUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SetStatusParams p) => repository.setBookStatus(p.id, p.status);
}

// ─────────────────────────── LESSONS ───────────────────────────
class GetLessonsUseCase implements UseCase<List<CmsLessonRow>, NoParams> {
  final CmsRepository repository;
  GetLessonsUseCase(this.repository);
  @override
  Future<Either<Failure, List<CmsLessonRow>>> call(NoParams params) => repository.getLessons();
}

class SaveLessonUseCase implements UseCase<CmsLessonRow, CmsLessonRow> {
  final CmsRepository repository;
  SaveLessonUseCase(this.repository);
  @override
  Future<Either<Failure, CmsLessonRow>> call(CmsLessonRow params) => repository.saveLesson(params);
}

class DeleteLessonUseCase implements UseCase<Unit, String> {
  final CmsRepository repository;
  DeleteLessonUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.deleteLesson(id);
}

class SetLessonStatusUseCase implements UseCase<Unit, SetStatusParams> {
  final CmsRepository repository;
  SetLessonStatusUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SetStatusParams p) => repository.setLessonStatus(p.id, p.status);
}

// ─────────────────────────── QUESTIONS ───────────────────────────
class GetQuestionsUseCase implements UseCase<List<CmsQuestionRow>, NoParams> {
  final CmsRepository repository;
  GetQuestionsUseCase(this.repository);
  @override
  Future<Either<Failure, List<CmsQuestionRow>>> call(NoParams params) => repository.getQuestions();
}

class SaveQuestionUseCase implements UseCase<CmsQuestionRow, CmsQuestionRow> {
  final CmsRepository repository;
  SaveQuestionUseCase(this.repository);
  @override
  Future<Either<Failure, CmsQuestionRow>> call(CmsQuestionRow params) => repository.saveQuestion(params);
}

class DeleteQuestionUseCase implements UseCase<Unit, String> {
  final CmsRepository repository;
  DeleteQuestionUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.deleteQuestion(id);
}

class SetQuestionStatusUseCase implements UseCase<Unit, SetStatusParams> {
  final CmsRepository repository;
  SetQuestionStatusUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SetStatusParams p) => repository.setQuestionStatus(p.id, p.status);
}

// ─────────────────────────── INVITE CODES ───────────────────────────
/// `type`: 'student' یا 'instructor' — تا هر دو تب کدهای دعوت (شاگرد/استاد)
/// از همین یک UseCase واحد و واقعی بگذرند.
class GetInviteCodesUseCase implements UseCase<List<CmsInviteCodeRow>, String> {
  final CmsRepository repository;
  GetInviteCodesUseCase(this.repository);
  @override
  Future<Either<Failure, List<CmsInviteCodeRow>>> call(String type) =>
      repository.getInviteCodes(type: type);
}

class GenerateInviteCodesParams extends Equatable {
  final int count;
  final String batchLabel;
  final String type; // 'student' یا 'instructor'
  const GenerateInviteCodesParams({required this.count, required this.batchLabel, this.type = 'student'});
  @override
  List<Object?> get props => [count, batchLabel, type];
}

class GenerateInviteCodesUseCase implements UseCase<Unit, GenerateInviteCodesParams> {
  final CmsRepository repository;
  GenerateInviteCodesUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(GenerateInviteCodesParams params) =>
      repository.generateInviteCodes(params.count, params.batchLabel, type: params.type);
}

class RevokeInviteCodeUseCase implements UseCase<Unit, String> {
  final CmsRepository repository;
  RevokeInviteCodeUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.revokeInviteCode(id);
}
