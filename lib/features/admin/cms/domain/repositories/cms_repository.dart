import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/cms_entities.dart';

abstract class CmsRepository {
  // Books
  Future<Either<Failure, List<CmsBookRow>>> getBooks();
  Future<Either<Failure, CmsBookRow>> saveBook(CmsBookRow row);
  Future<Either<Failure, Unit>> deleteBook(String id);
  Future<Either<Failure, Unit>> setBookStatus(String id, ContentStatus status);

  // Lessons
  Future<Either<Failure, List<CmsLessonRow>>> getLessons();
  Future<Either<Failure, CmsLessonRow>> saveLesson(CmsLessonRow row);
  Future<Either<Failure, Unit>> deleteLesson(String id);
  Future<Either<Failure, Unit>> setLessonStatus(String id, ContentStatus status);

  // Questions
  Future<Either<Failure, List<CmsQuestionRow>>> getQuestions();
  Future<Either<Failure, CmsQuestionRow>> saveQuestion(CmsQuestionRow row);
  Future<Either<Failure, Unit>> deleteQuestion(String id);
  Future<Either<Failure, Unit>> setQuestionStatus(String id, ContentStatus status);

  // Invite codes
  Future<Either<Failure, List<CmsInviteCodeRow>>> getInviteCodes();
  Future<Either<Failure, Unit>> generateInviteCodes(int count, String batchLabel);
  Future<Either<Failure, Unit>> revokeInviteCode(String id);
}
