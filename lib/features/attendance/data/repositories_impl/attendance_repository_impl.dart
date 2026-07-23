import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/attendance_entities.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../datasources/attendance_remote_datasource.dart' show AttendanceDataSource;

class AttendanceRepositoryImpl implements AttendanceRepository {
  final AttendanceDataSource dataSource;
  AttendanceRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, AttendanceSummary>> getSummary(String studentId) async {
    try {
      return Right(await dataSource.getSummary(studentId));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Failure _mapApi(ApiException e) => e.isNetworkError
      ? NetworkFailure(e.message)
      : (e.type == ApiErrorType.badRequest ? ValidationFailure(e.message) : ServerFailure(e.message, code: e.code));
}
