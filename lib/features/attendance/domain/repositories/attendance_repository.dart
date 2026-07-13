import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/attendance_entities.dart';

abstract class AttendanceRepository {
  /// طبق `GET /attendance/{studentId}/summary` بخش ۱۹.۵.
  Future<Either<Failure, AttendanceSummary>> getSummary(String studentId);
}
