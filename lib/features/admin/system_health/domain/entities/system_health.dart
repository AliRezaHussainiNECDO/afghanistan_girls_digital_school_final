import 'package:equatable/equatable.dart';

/// وضعیت کلی سیستم — بر اساس بدترین نتیجهٔ بررسی‌ها (بخش پایش زندهٔ مدیر).
enum SystemOverallStatus { operational, degraded, down }

/// وضعیت یک بررسی مجزا (دیتابیس، فضای ذخیره‌سازی، و غیره).
enum ServiceCheckStatus { ok, warning, error }

/// نتیجهٔ یک بررسی مجزا از سرور.
///
/// `id` عمداً رشته‌ای و باز است — بک‌اند می‌تواند در آینده بررسی‌های جدید
/// اضافه کند بدون نیاز به تغییر این مدل یا نسخهٔ اپ؛ شناسه‌های ناشناخته در
/// presentation با آیکون/برچسب پیش‌فرض نمایش داده می‌شوند (نگاه کنید به
/// `SystemHealthSection`).
class ServiceCheck extends Equatable {
  final String id;
  final ServiceCheckStatus status;
  final int? latencyMs;
  final String? detailFa;
  final String? detailEn;

  const ServiceCheck({
    required this.id,
    required this.status,
    this.latencyMs,
    this.detailFa,
    this.detailEn,
  });

  @override
  List<Object?> get props => [id, status, latencyMs, detailFa, detailEn];
}

/// عکس فوری کامل از سلامت سیستم — لحظهٔ بررسی + وضعیت کلی + جزئیات هر بخش.
class SystemHealth extends Equatable {
  final DateTime timestamp;
  final SystemOverallStatus overallStatus;
  final List<ServiceCheck> checks;

  const SystemHealth({
    required this.timestamp,
    required this.overallStatus,
    required this.checks,
  });

  @override
  List<Object?> get props => [timestamp, overallStatus, checks];
}
