import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/grade_map.dart';
import '../repositories/grade_map_repository.dart';

class GetGradeMapUseCase implements UseCase<GradeMap, String> {
  final GradeMapRepository repository;
  GetGradeMapUseCase(this.repository);

  @override
  Future<Either<Failure, GradeMap>> call(String studentId) {
    return repository.getGradeMap(studentId);
  }
}
