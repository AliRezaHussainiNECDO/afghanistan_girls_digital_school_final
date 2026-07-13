import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../../../../../shared_models/seminar.dart';

/// مدیریت کامل سمینارها برای Super Admin — طبق اصلاح ۲.۲ سند
/// (مدیر تمام امکانات این بخش را دارد).
abstract class AdminSeminarsRepository {
  Future<Either<Failure, List<Seminar>>> getAll();

  Future<Either<Failure, Unit>> create({
    required String title,
    required String description,
    String? instructorId,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    int? capacity,
    SeminarAudience audience,
    String meetingLink,
  });

  Future<Either<Failure, Unit>> update({
    required String id,
    required String title,
    required String description,
    String? instructorId,
    required String instructorName,
    required DateTime scheduledStart,
    required int durationMinutes,
    required SeminarStatus status,
    int? capacity,
    SeminarAudience? audience,
    String meetingLink,
  });

  Future<Either<Failure, Unit>> delete(String id);

  Future<Either<Failure, Unit>> setStatus(String id, SeminarStatus status);
}
