import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/attendance_entities.dart';
import '../repositories/attendance_repository.dart';

class GetAttendanceSummaryUseCase implements UseCase<AttendanceSummary, String> {
  final AttendanceRepository repository;
  GetAttendanceSummaryUseCase(this.repository);
  @override
  Future<Either<Failure, AttendanceSummary>> call(String studentId) => repository.getSummary(studentId);
}
