import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared_models/seminar.dart';
import '../../domain/repositories/instructor_repository.dart';
import '../../../../core/network/api_client.dart';
import '../datasources/instructor_remote_datasource.dart' show InstructorDataSource;

class InstructorRepositoryImpl implements InstructorRepository {
  final InstructorDataSource dataSource;
  InstructorRepositoryImpl(this.dataSource);

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
  Future<Either<Failure, List<Seminar>>> getMySeminars(String instructorId) =>
      _guard(() => dataSource.getMySeminars(instructorId));

  @override
  Future<Either<Failure, Unit>> createSeminar({
    required String instructorId,
    required String instructorName,
    required String title,
    required String description,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience = SeminarAudience.students,
    String meetingLink = '',
  }) =>
      _guard(() async {
        await dataSource.createSeminar(
          instructorId: instructorId,
          instructorName: instructorName,
          title: title,
          description: description,
          scheduledStart: scheduledStart,
          durationMinutes: durationMinutes,
          capacity: capacity,
          audience: audience,
          meetingLink: meetingLink,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> updateSeminar({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink = '',
  }) =>
      _guard(() async {
        await dataSource.updateSeminar(
          id: id,
          title: title,
          description: description,
          scheduledStart: scheduledStart,
          durationMinutes: durationMinutes,
          capacity: capacity,
          audience: audience,
          meetingLink: meetingLink,
        );
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> deleteSeminar(String id) => _guard(() async {
        await dataSource.deleteSeminar(id);
        return unit;
      });

  @override
  Future<Either<Failure, Unit>> setStatus(String id, SeminarStatus status) =>
      _guard(() async {
        await dataSource.setStatus(id, status);
        return unit;
      });
}
