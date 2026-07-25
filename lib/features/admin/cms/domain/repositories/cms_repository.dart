import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/cms_entities.dart';

abstract class CmsRepository {
  // Lessons
  Future<Either<Failure, List<CmsLessonRow>>> getLessons();
  Future<Either<Failure, CmsLessonRow>> saveLesson(CmsLessonRow row);
  Future<Either<Failure, Unit>> deleteLesson(String id);
  Future<Either<Failure, Unit>> setLessonStatus(String id, ContentStatus status);

  // Invite codes — `type`: 'student' (پیش‌فرض) یا 'instructor'.
  Future<Either<Failure, List<CmsInviteCodeRow>>> getInviteCodes({String type = 'student'});
  Future<Either<Failure, Unit>> generateInviteCodes(int count, String batchLabel, {String type = 'student'});
  Future<Either<Failure, Unit>> revokeInviteCode(String id);
}
