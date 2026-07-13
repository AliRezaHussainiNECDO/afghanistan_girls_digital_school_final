import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../../../../shared_models/seminar.dart';
import '../repositories/instructor_repository.dart';

class GetMySeminarsUseCase implements UseCase<List<Seminar>, String> {
  final InstructorRepository repository;
  GetMySeminarsUseCase(this.repository);
  @override
  Future<Either<Failure, List<Seminar>>> call(String instructorId) =>
      repository.getMySeminars(instructorId);
}

class CreateSeminarParams extends Equatable {
  final String instructorId;
  final String instructorName;
  final String title;
  final String description;
  final DateTime scheduledStart;
  final int durationMinutes;
  final int? capacity;
  final SeminarAudience audience;
  final String meetingLink;
  const CreateSeminarParams({
    required this.instructorId,
    required this.instructorName,
    required this.title,
    this.description = '',
    required this.scheduledStart,
    required this.durationMinutes,
    this.capacity,
    this.audience = SeminarAudience.students,
    this.meetingLink = '',
  });
  @override
  List<Object?> get props =>
      [instructorId, title, description, scheduledStart, durationMinutes, capacity, audience, meetingLink];
}

class CreateSeminarUseCase implements UseCase<Unit, CreateSeminarParams> {
  final InstructorRepository repository;
  CreateSeminarUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(CreateSeminarParams params) => repository.createSeminar(
        instructorId: params.instructorId,
        instructorName: params.instructorName,
        title: params.title,
        description: params.description,
        scheduledStart: params.scheduledStart,
        durationMinutes: params.durationMinutes,
        capacity: params.capacity,
        audience: params.audience,
        meetingLink: params.meetingLink,
      );
}

class UpdateSeminarParams extends Equatable {
  final String id;
  final String title;
  final String description;
  final DateTime scheduledStart;
  final int durationMinutes;
  final int? capacity;
  final SeminarAudience? audience;
  final String meetingLink;
  const UpdateSeminarParams({
    required this.id,
    required this.title,
    this.description = '',
    required this.scheduledStart,
    required this.durationMinutes,
    this.capacity,
    this.audience,
    this.meetingLink = '',
  });
  @override
  List<Object?> get props =>
      [id, title, description, scheduledStart, durationMinutes, capacity, audience, meetingLink];
}

class UpdateSeminarUseCase implements UseCase<Unit, UpdateSeminarParams> {
  final InstructorRepository repository;
  UpdateSeminarUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(UpdateSeminarParams params) => repository.updateSeminar(
        id: params.id,
        title: params.title,
        description: params.description,
        scheduledStart: params.scheduledStart,
        durationMinutes: params.durationMinutes,
        capacity: params.capacity,
        audience: params.audience,
        meetingLink: params.meetingLink,
      );
}

class DeleteSeminarUseCase implements UseCase<Unit, String> {
  final InstructorRepository repository;
  DeleteSeminarUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(String id) => repository.deleteSeminar(id);
}

class SetSeminarStatusParams extends Equatable {
  final String id;
  final SeminarStatus status;
  const SetSeminarStatusParams({required this.id, required this.status});
  @override
  List<Object?> get props => [id, status];
}

/// شروع/پایان جلسهٔ زنده — State Machine بخش ۱۲.۲.
class SetSeminarStatusUseCase implements UseCase<Unit, SetSeminarStatusParams> {
  final InstructorRepository repository;
  SetSeminarStatusUseCase(this.repository);
  @override
  Future<Either<Failure, Unit>> call(SetSeminarStatusParams params) =>
      repository.setStatus(params.id, params.status);
}
