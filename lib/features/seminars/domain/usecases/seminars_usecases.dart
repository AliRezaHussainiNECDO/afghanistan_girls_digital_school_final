import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../shared_models/seminar.dart';
import '../repositories/seminars_repository.dart';

class GetUpcomingSeminarsUseCase implements UseCase<List<Seminar>, SeminarAudience> {
  final SeminarsRepository repository;
  GetUpcomingSeminarsUseCase(this.repository);
  @override
  Future<Either<Failure, List<Seminar>>> call(SeminarAudience audience) =>
      repository.getUpcoming(audience);
}

class GetSeminarByIdUseCase implements UseCase<Seminar, String> {
  final SeminarsRepository repository;
  GetSeminarByIdUseCase(this.repository);
  @override
  Future<Either<Failure, Seminar>> call(String id) => repository.getById(id);
}

class RegisterSeminarParams extends Equatable {
  final String seminarId;
  final String userId;
  const RegisterSeminarParams({required this.seminarId, required this.userId});
  @override
  List<Object?> get props => [seminarId, userId];
}

/// ثبت‌نام فقط یک‌بار — تکراری بودن در Store بررسی و رد می‌شود.
class RegisterSeminarUseCase implements UseCase<Unit, RegisterSeminarParams> {
  final SeminarsRepository repository;
  RegisterSeminarUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(RegisterSeminarParams params) =>
      repository.register(params.seminarId, params.userId);
}
