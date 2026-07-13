import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../domain/entities/grade_map.dart';
import '../../domain/repositories/grade_map_repository.dart';
import '../datasources/grade_map_remote_datasource.dart' show GradeMapDataSource;

/// طبق الگوی بخش ۲۴.۳ سند. به قرارداد `GradeMapDataSource` وابسته است تا
/// با Mock یا Remote بدون تغییر کار کند.
class GradeMapRepositoryImpl implements GradeMapRepository {
  final GradeMapDataSource dataSource;
  GradeMapRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, GradeMap>> getGradeMap(String studentId) async {
    try {
      final result = await dataSource.getGradeMap(studentId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
