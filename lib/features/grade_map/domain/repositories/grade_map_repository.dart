import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/grade_map.dart';

/// Interface انتزاعی — عیناً طبق مثال صریح بخش ۲۴.۳ سند.
abstract class GradeMapRepository {
  Future<Either<Failure, GradeMap>> getGradeMap(String studentId, {required int grade});
}
