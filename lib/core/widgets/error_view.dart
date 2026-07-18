import 'package:flutter/material.dart';
import '../errors/failures.dart';
import '../localization/app_localizations.dart';
import 'app_primary_button.dart';

/// نگاشت یک خطای گرفته‌شده (`catch (e)` / `AsyncValue.error`) به متن قابل
/// نمایش و ترجمه‌شده برای کاربر.
///
/// چرا این تابع لازم است: پیام‌های پیش‌فرض `NetworkFailure`/`CacheFailure`/
/// `PermissionFailure` در `core/errors/failures.dart` عمداً فقط فارسی
/// هستند — چون آن کلاس‌ها در لایهٔ domain مستقل از Flutter تعریف شده‌اند و
/// نمی‌توانند مستقیماً از `context.tr()` استفاده کنند (دسترسی به
/// BuildContext ندارند). این تابع همان نگاشتِ درست را در لایهٔ UI انجام
/// می‌دهد: نوع Failure را می‌بیند و به‌جای پیام پیش‌فرض فارسیِ آن، کلید
/// ترجمهٔ متناظرش را برمی‌گرداند. برای `ServerFailure`/`ValidationFailure`
/// (که پیام‌شان از سرور یا اعتبارسنجی فرم می‌آید و از قبل معنادار است)
/// همان `message` بدون تغییر برگردانده می‌شود.
///
/// خطاهای غیر از `Failure` (مثل رشته‌های `throw 'متن'` در
/// `StudentInviteStore`/`GuardianLinkStore` که خودشان از قبل بر اساس زبان
/// فعال ساخته شده‌اند، یا هر `Exception` دیگر) هم پشتیبانی می‌شوند —
/// به‌سادگی `toString()` می‌شوند.
String localizeError(BuildContext context, Object error) {
  if (error is NetworkFailure) return context.tr('errors.network');
  if (error is CacheFailure) return context.tr('errors.cache');
  if (error is PermissionFailure) return context.tr('errors.permission');
  if (error is Failure) return error.message;
  return error.toString();
}

class ErrorView extends StatelessWidget {
  /// متن آمادهٔ نمایش. اگر [error] هم داده شود، [error] اولویت دارد و از
  /// طریق [localizeError] به متن نگاشت می‌شود؛ [message] برای مواردی است که
  /// از قبل یک رشتهٔ نهایی (نه یک شیٔ خطا) در دست دارید.
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;

  const ErrorView({super.key, this.message, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resolvedMessage =
        error != null ? localizeError(context, error!) : (message ?? context.tr('common.error'));
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.sentiment_dissatisfied_rounded, size: 34, color: scheme.error),
            ),
            const SizedBox(height: 16),
            Text(
              resolvedMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: 180,
                child: AppPrimaryButton(
                  label: context.tr('common.retry'),
                  onPressed: onRetry,
                  icon: Icons.refresh_rounded,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
