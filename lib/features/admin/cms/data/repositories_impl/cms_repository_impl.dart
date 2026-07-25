import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/network/api_client.dart';
import '../../domain/entities/cms_entities.dart';
import '../../domain/repositories/cms_repository.dart';
import '../datasources/cms_remote_datasource.dart' show CmsDataSource;

class CmsRepositoryImpl implements CmsRepository {
  final CmsDataSource dataSource;
  CmsRepositoryImpl(this.dataSource);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Right(await body());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));

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
