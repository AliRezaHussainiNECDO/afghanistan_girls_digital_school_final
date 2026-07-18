import 'package:equatable/equatable.dart';

/// Base class for all domain-level failures.
///
/// طبق بخش ۲۴.۱ سند: لایهٔ domain مستقل از Flutter/Dio است، پس خطاها هم
/// به‌صورت انواع Dart خام (نه Exception خام HTTP) مدل‌سازی می‌شوند.
abstract class Failure extends Equatable {
  final String message;

  const Failure(this.message);

  @override
  List<Object?> get props => [message];

  // Equatable's default toString() prints `ClassName(message)` — that
  // class-name prefix would leak into the UI wherever code does
  // `e.toString()` on a caught Failure (a very common pattern in this app's
  // AsyncValue.error handlers). Overriding it here keeps `toString()` equal
  // to the plain message for every Failure subtype, independent of the
  // localizeError() mapping in `core/widgets/error_view.dart`.
  @override
  String toString() => message;
}

/// خطای شبکه (در فاز ۱ عملاً رخ نمی‌دهد چون DataSource ها Mock هستند،
/// اما لایهٔ domain از ابتدا برای فاز ۲ به بعد آماده است).
class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'خطای اتصال به شبکه']);
}

/// خطای برگشتی از سرور (مطابق قرارداد خطای بخش ۱۹.۱۰ سند).
class ServerFailure extends Failure {
  final String? code;

  const ServerFailure(super.message, {this.code});

  @override
  List<Object?> get props => [message, code];
}

/// خطای Cache محلی (بخش ۲۲ — پشتیبانی آفلاین).
class CacheFailure extends Failure {
  const CacheFailure([super.message = 'داده‌ای در حافظهٔ محلی یافت نشد']);
}

/// خطای اعتبارسنجی فرم (سمت کلاینت، فقط برای UX سریع — طبق بخش ۴.۳).
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// خطای عدم دسترسی (RBAC) — طبق بخش ۲.۲/۲۰.۴.
class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'شما اجازهٔ دسترسی به این بخش را ندارید']);
}
