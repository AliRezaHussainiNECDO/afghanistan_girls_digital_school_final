import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../domain/entities/cms_entities.dart';
import '../../domain/repositories/cms_repository.dart';
import '../datasources/cms_remote_datasource.dart' show CmsDataSource;

class CmsRepositoryImpl implements CmsRepository {
  final CmsDataSource dataSource;
  CmsRepositoryImpl(this.dataSource);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  // Books
  @override
  Future<Either<Failure, List<CmsBookRow>>> getBooks() => _guard(dataSource.getBooks);
  @override
  Future<Either<Failure, CmsBookRow>> saveBook(CmsBookRow row) => _guard(() => dataSource.saveBook(row));
  @override
  Future<Either<Failure, Unit>> deleteBook(String id) => _guard(() async {
        await dataSource.deleteBook(id);
        return unit;
      });
  @override
  Future<Either<Failure, Unit>> setBookStatus(String id, ContentStatus status) => _guard(() async {
        await dataSource.setBookStatus(id, status);
        return unit;
      });

  // Lessons
  @override
  Future<Either<Failure, List<CmsLessonRow>>> getLessons() => _guard(dataSource.getLessons);
  @override
  Future<Either<Failure, CmsLessonRow>> saveLesson(CmsLessonRow row) => _guard(() => dataSource.saveLesson(row));
  @override
  Future<Either<Failure, Unit>> deleteLesson(String id) => _guard(() async {
        await dataSource.deleteLesson(id);
        return unit;
      });
  @override
  Future<Either<Failure, Unit>> setLessonStatus(String id, ContentStatus status) => _guard(() async {
        await dataSource.setLessonStatus(id, status);
        return unit;
      });

  // Questions
  @override
  Future<Either<Failure, List<CmsQuestionRow>>> getQuestions() => _guard(dataSource.getQuestions);
  @override
  Future<Either<Failure, CmsQuestionRow>> saveQuestion(CmsQuestionRow row) =>
      _guard(() => dataSource.saveQuestion(row));
  @override
  Future<Either<Failure, Unit>> deleteQuestion(String id) => _guard(() async {
        await dataSource.deleteQuestion(id);
        return unit;
      });
  @override
  Future<Either<Failure, Unit>> setQuestionStatus(String id, ContentStatus status) => _guard(() async {
        await dataSource.setQuestionStatus(id, status);
        return unit;
      });

  // Invite codes
  @override
  Future<Either<Failure, List<CmsInviteCodeRow>>> getInviteCodes({String type = 'student'}) =>
      _guard(() => dataSource.getInviteCodes(type: type));
  @override
  Future<Either<Failure, Unit>> generateInviteCodes(int count, String batchLabel, {String type = 'student'}) =>
      _guard(() async {
        await dataSource.generateInviteCodes(count, batchLabel, type: type);
        return unit;
      });
  @override
  Future<Either<Failure, Unit>> revokeInviteCode(String id) => _guard(() async {
        await dataSource.revokeInviteCode(id);
        return unit;
      });
}
