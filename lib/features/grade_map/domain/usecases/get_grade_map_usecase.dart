import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../entities/grade_map.dart';
import '../repositories/grade_map_repository.dart';

/// رفع اشکال: قبلاً این UseCase فقط `studentId` می‌گرفت و همیشه صنف فعال
/// را واکشی می‌کرد — امکان درخواست صریح یک صنفِ مشخص (برای مرور صنوف
/// پایین‌ترِ تکمیل‌شده) وجود نداشت.
class GetGradeMapParams extends Equatable {
  final String studentId;
  final int grade;
  const GetGradeMapParams({required this.studentId, required this.grade});

  @override
  List<Object?> get props => [studentId, grade];
}

class GetGradeMapUseCase implements UseCase<GradeMap, GetGradeMapParams> {
  final GradeMapRepository repository;
  GetGradeMapUseCase(this.repository);

  @override
  Future<Either<Failure, GradeMap>> call(GetGradeMapParams params) {
    return repository.getGradeMap(params.studentId, grade: params.grade);
  }
}
