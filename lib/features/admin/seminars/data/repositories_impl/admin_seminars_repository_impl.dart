import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../shared_models/seminar.dart';
import '../../domain/repositories/admin_seminars_repository.dart';
import '../../../../../core/network/api_client.dart';
import '../datasources/admin_seminars_remote_datasource.dart' show AdminSeminarsDataSource;

class AdminSeminarsRepositoryImpl implements AdminSeminarsRepository {
  final AdminSeminarsDataSource dataSource;
  AdminSeminarsRepositoryImpl(this.dataSource);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      return Right(await action());
    } on ApiException catch (e) {
      return Left(e.isNetworkError
          ? NetworkFailure(e.message)
          : ServerFailure(e.message, code: e.code));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Seminar>>> getAll() => _guard(() => dataSource.getAll());

  @override
  Future<Either<Failure, Unit>> create({
    required String title,
    required String description,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience = SeminarAudience.students,
    String meetingLink = '',
  }) =>
      _guard(() async {
        await dataSource.create(
          title: title,
          description: description,
          instructorName: instructorName,
          scheduledStart: scheduledStart,
          durationMinutes: durationMinutes,
          capacity: capacity,
          audience: audience,
          meetingLink: meetingLink,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> update({
    required String id,
    required String title,
    required String description,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    required SeminarStatus status,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink = '',
  }) =>
      _guard(() async {
        await dataSource.update(
          id: id,
          title: title,
          description: description,
          instructorName: instructorName,
          scheduledStart: scheduledStart,
          durationMinutes: durationMinutes,
          status: status,
          capacity: capacity,
          audience: audience,
          meetingLink: meetingLink,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> delete(String id) => _guard(() async {
        await dataSource.delete(id);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> setStatus(String id, SeminarStatus status) =>
      _guard(() async {
        await dataSource.setStatus(id, status);
        return unit;
      });
}
