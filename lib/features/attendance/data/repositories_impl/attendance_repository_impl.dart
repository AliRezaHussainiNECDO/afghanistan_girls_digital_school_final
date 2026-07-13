import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
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
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
