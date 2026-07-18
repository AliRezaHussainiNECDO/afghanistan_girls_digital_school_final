import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';
import '../localization/app_localizations.dart';

/// مدیریت‌کنندهٔ مرکزی خطا.
///
/// همهٔ خطاهای مدیریت‌نشدهٔ اپ (فریم‌ورک، پلتفرم، Zone) به اینجا می‌رسند.
/// در فاز فعلی صرفاً خطا را به‌صورت ساختاریافته لاگ می‌کند و در حافظه نگه
/// می‌دارد؛ در فازهای بعد می‌توان همین نقطه را به یک سرویس گزارش خطا
/// (مانند Sentry/Crashlytics) وصل کرد بدون تغییر در بقیهٔ اپ.
class AppErrorHandler {
  AppErrorHandler._();

  /// آخرین خطاهای ثبت‌شده (برای صفحهٔ تشخیص/دیباگ داخلی، حداکثر ۵۰ مورد).
  static final List<AppErrorEntry> recent = <AppErrorEntry>[];

  static void record(Object error, StackTrace? stack, {String context = 'unknown'}) {
    final entry = AppErrorEntry(
      error: error.toString(),
      stack: stack?.toString() ?? '',
      context: context,
      time: DateTime.now(),
    );
    recent.insert(0, entry);
    if (recent.length > 50) recent.removeRange(50, recent.length);

    // در حالت دیباگ روی کنسول چاپ کن تا هنگام توسعه دیده شود.
    if (kDebugMode) {
      debugPrint('┌─ [AppError/$context] ${entry.time.toIso8601String()}');
      debugPrint('│  ${entry.error}');
      if (entry.stack.isNotEmpty) {
        final firstLines = entry.stack.split('\n').take(6).join('\n│  ');
        debugPrint('│  $firstLines');
      }
      debugPrint('└─────────────────────────────');
    }
  }
}

class AppErrorEntry {
  final String error;
  final String stack;
  final String context;
  final DateTime time;
  const AppErrorEntry({
    required this.error,
    required this.stack,
    required this.context,
    required this.time,
  });
}

/// جایگزین صفحهٔ خطای پیش‌فرض Flutter. به‌جای Crash یا صفحهٔ قرمز، یک کارت
/// آرام و قابل‌فهم نشان می‌دهد. کاملاً خوداتکاست (Directionality/Material
/// داخلی دارد) چون ممکن است در هر نقطه‌ای از درخت ویجت ساخته شود — حتی
/// دقیقاً جایی که خودِ درخت ویجت (و شاید حتی Localizations بالادستی) خراب
/// است. به همین دلیل هر دو متن اینجا با `_safeTr` خوانده می‌شوند: تلاش برای
/// `context.tr()` و در صورت هر نوع خطا (مثلاً نبود Localizations در
/// بالادست)، بازگشت بی‌صدا به همان متن ثابت فارسی قبلی — تا این صفحهٔ نجات
/// خودش هرگز باعث یک خطای تازه نشود.
class FriendlyErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const FriendlyErrorWidget({super.key, required this.details});

  /// `context.tr(key)` را امتحان می‌کند؛ اگر به هر دلیلی (مثلاً نبود
  /// Localizations در درخت خراب) خطا بدهد، به [fallback] برمی‌گردد.
  static String _safeTr(BuildContext context, String key, String fallback) {
    try {
      return context.tr(key);
    } catch (_) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _safeTr(
        context, 'errors.friendlyTitle', 'مشکلی در نمایش این بخش پیش آمد');
    final subtitle = _safeTr(
        context,
        'errors.friendlySubtitle',
        'نگران نباشید — برنامه بسته نشده است. می‌توانید به صفحهٔ قبل برگردید و دوباره تلاش کنید.');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: AppColors.cream,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.orange100,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sentiment_dissatisfied_rounded,
                      size: 34, color: AppColors.orange600),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.ink900),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.ink700, height: 1.6),
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sand100,
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Text(
                      details.exceptionAsString(),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.ink700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
