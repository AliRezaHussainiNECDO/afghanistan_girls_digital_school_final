import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../core/usecase/usecase.dart';
import '../../../../../shared_models/seminar.dart';
import '../repositories/admin_seminars_repository.dart';

class GetAdminSeminarsUseCase implements UseCase<List<Seminar>, NoParams> {
  final AdminSeminarsRepository repository;
  GetAdminSeminarsUseCase(this.repository);
  @override
  Future<Either<Failure, List<Seminar>>> call(NoParams params) => repository.getAll();
}

class CreateAdminSeminarParams extends Equatable {
  final String title;
  final String description;
  final String? instructorId;
  final String instructorName;
  final DateTime scheduledStart;
  final int durationMinutes;
  final int? capacity;
  final SeminarAudience audience;
  final String meetingLink;
  const CreateAdminSeminarParams({
    required this.title,
    this.description = '',
    this.instructorId,
    required this.instructorName,
    required this.scheduledStart,
    required this.durationMinutes,
    this.capacity,
    this.audience = SeminarAudience.students,
    this.meetingLink = '',
  });
  @override
  List<Object?> get props => [
        title,
        description,
        instructorId,
        instructorName,
        scheduledStart,
        durationMinutes,
        capacity,
        audience,
        meetingLink,
      ];
}

class CreateAdminSeminarUseCase implements UseCase<Unit, CreateAdminSeminarParams> {
  final AdminSeminarsRepository repository;
  CreateAdminSeminarUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(CreateAdminSeminarParams params) => repository.create(
        title: params.title,
        description: params.description,
        instructorId: params.instructorId,
        instructorName: params.instructorName,
        scheduledStart: params.scheduledStart,
        durationMinutes: params.durationMinutes,
        capacity: params.capacity,
        audience: params.audience,
        meetingLink: params.meetingLink,
      );
}

class UpdateAdminSeminarParams extends Equatable {
  final String id;
  final String title;
  final String description;
  final String? instructorId;
  final String instructorName;
  final DateTime scheduledStart;
  final int durationMinutes;
  final SeminarStatus status;
  final int? capacity;
  final SeminarAudience? audience;
  final String meetingLink;
  const UpdateAdminSeminarParams({
    required this.id,
    required this.title,
    this.description = '',
    this.instructorId,
    required this.instructorName,
    required this.scheduledStart,
    required this.durationMinutes,
    required this.status,
    this.capacity,
    this.audience,
    this.meetingLink = '',
  });
  @override
  List<Object?> get props => [
        id,
        title,
        description,
        instructorId,
        instructorName,
        scheduledStart,
        durationMinutes,
        status,
        capacity,
        audience,
        meetingLink,
      ];
}

class UpdateAdminSeminarUseCase implements UseCase<Unit, UpdateAdminSeminarParams> {
  final AdminSeminarsRepository repository;
  UpdateAdminSeminarUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(UpdateAdminSeminarParams params) => repository.update(
        id: params.id,
        title: params.title,
        description: params.description,
        instructorId: params.instructorId,
        instructorName: params.instructorName,
        scheduledStart: params.scheduledStart,
        durationMinutes: params.durationMinutes,
        status: params.status,
        capacity: params.capacity,
        audience: params.audience,
        meetingLink: params.meetingLink,
      );
}

class DeleteAdminSeminarUseCase implements UseCase<Unit, String> {
  final AdminSeminarsRepository repository;
  DeleteAdminSeminarUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.delete(id);
}

class SetAdminSeminarStatusParams extends Equatable {
  final String id;
  final SeminarStatus status;
  const SetAdminSeminarStatusParams({required this.id, required this.status});
  @override
  List<Object?> get props => [id, status];
}

class SetAdminSeminarStatusUseCase implements UseCase<Unit, SetAdminSeminarStatusParams> {
  final AdminSeminarsRepository repository;
  SetAdminSeminarStatusUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SetAdminSeminarStatusParams params) =>
      repository.setStatus(params.id, params.status);
}
