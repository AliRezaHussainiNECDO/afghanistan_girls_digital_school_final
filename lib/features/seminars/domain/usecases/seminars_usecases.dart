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

/// لغو ثبت‌نام (۲۴ جولای) — تنها پیش از شروع/پایان سمینار مجاز است.
class UnregisterSeminarUseCase implements UseCase<Unit, RegisterSeminarParams> {
  final SeminarsRepository repository;
  UnregisterSeminarUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(RegisterSeminarParams params) =>
      repository.unregister(params.seminarId, params.userId);
}

class SetSeminarStatusParams extends Equatable {
  final String seminarId;
  final SeminarStatus status;
  const SetSeminarStatusParams({required this.seminarId, required this.status});
  @override
  List<Object?> get props => [seminarId, status];
}

/// شروع/پایان دستی سمینار از اتاق داخلی — تا وضعیت واقعاً روی سرور ثبت و
/// برای همهٔ نقش‌ها (شاگرد/والد/استاد/مدیر) هماهنگ شود.
class SetSeminarStatusUseCase implements UseCase<Unit, SetSeminarStatusParams> {
  final SeminarsRepository repository;
  SetSeminarStatusUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SetSeminarStatusParams params) =>
      repository.setStatus(params.seminarId, params.status);
}
