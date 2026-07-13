import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared_models/seminar.dart';

abstract class InstructorRepository {
  Future<Either<Failure, List<Seminar>>> getMySeminars(String instructorId);

  /// طبق `POST /api/v1/seminars` بخش ۱۹.۸ سند.
  Future<Either<Failure, Unit>> createSeminar({
    required String instructorId,
    required String instructorName,
    required String title,
    required String description,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience,
    String meetingLink,
  });

  /// ویرایش سمینار خود استاد.
  Future<Either<Failure, Unit>> updateSeminar({
    required String id,
    required String title,
    required String description,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink,
  });

  /// حذف سمینار خود استاد.
  Future<Either<Failure, Unit>> deleteSeminar(String id);

  /// تغییر وضعیت (شروع زنده / پایان) — `PATCH /seminars/{id}/status` بخش ۱۹.۸.
  Future<Either<Failure, Unit>> setStatus(String id, SeminarStatus status);
}
