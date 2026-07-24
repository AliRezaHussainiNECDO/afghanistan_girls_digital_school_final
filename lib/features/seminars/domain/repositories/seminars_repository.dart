import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../shared_models/seminar.dart';

abstract class SeminarsRepository {
  /// فهرست سمینارهای قابل مشاهده برای مخاطب مشخص (شاگردان/والدین).
  Future<Either<Failure, List<Seminar>>> getUpcoming(SeminarAudience audience);

  /// جزئیات یک سمینار (برای اتاق ویدیو کنفرانس).
  Future<Either<Failure, Seminar>> getById(String id);

  /// طبق `POST /seminars/{id}/register` بخش ۱۹.۸ — هر کاربر فقط یک‌بار.
  Future<Either<Failure, Unit>> register(String seminarId, String userId);

  /// لغو ثبت‌نام (۲۴ جولای) — طبق `DELETE /seminars/{id}/register`؛ فقط
  /// پیش از شروع/پایان سمینار مجاز است.
  Future<Either<Failure, Unit>> unregister(String seminarId, String userId);

  /// تغییر وضعیت سمینار (شروع/پایان دستی از اتاق داخلی) — طبق
  /// `PATCH /seminars/{id}/status`؛ فقط میزبان (استاد/مدیر) مجاز است.
  Future<Either<Failure, Unit>> setStatus(String seminarId, SeminarStatus status);
}
