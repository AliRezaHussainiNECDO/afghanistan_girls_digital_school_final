import 'dart:async' show unawaited;
import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/theme/design_tokens.dart';
import '../localization/app_localizations.dart';
import '../network/api_client.dart' show kApiBaseUrl;

/// مدیریت‌کنندهٔ مرکزی خطا.
///
/// همهٔ خطاهای مدیریت‌نشدهٔ اپ (فریم‌ورک، پلتفرم، Zone — نگاه کن main.dart)
/// به اینجا می‌رسند. علاوه بر لاگ محلی (حافظه/کنسول)، از «گزارش خطاهای
/// برنامه» (Migration 0046) به بعد، هر خطا به‌صورت خاموش (fire-and-forget)
/// به `POST /api/v1/errors` هم گزارش می‌شود — دقیقاً همان نقطه‌ای که این
/// کلاس از قبل پیش‌بینی کرده بود («در فازهای بعد می‌توان به یک سرویس گزارش
/// خطا وصل کرد»). نتیجه در پنل مدیر («گزارش خطاها» — routes/errorLogs.ts +
/// features/admin/error_logs) با کد خطا، تاریخ/روز/ساعت دقیق، و دکمهٔ «کپی
/// برای هوش مصنوعی» قابل مرور است.
///
/// این کلاس عمداً از ApiClient/Riverpod استفاده نمی‌کند: `FlutterError.onError`
/// در main.dart پیش از ساخته‌شدن `ProviderScope` تنظیم می‌شود، پس یک نمونهٔ
/// سبک و مستقل `Dio` با baseUrl همان [kApiBaseUrl] کافی است. Endpoint ثبت
/// خطا عمداً بدون نیاز به Bearer است (routes/errorLogs.ts) چون باید کرش
/// کاربر مهمان/واردنشده را هم بگیرد.
class AppErrorHandler {
  AppErrorHandler._();

  /// آخرین خطاهای ثبت‌شده (برای صفحهٔ تشخیص/دیباگ داخلی، حداکثر ۵۰ مورد).
  static final List<AppErrorEntry> recent = <AppErrorEntry>[];

  static final Dio _reportDio = Dio(BaseOptions(
    baseUrl: kApiBaseUrl,
    connectTimeout: const Duration(seconds: 6),
    sendTimeout: const Duration(seconds: 6),
    receiveTimeout: const Duration(seconds: 6),
  ));

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

    _reportToBackend(entry);
  }

  /// نگاشت `context` هر سه قلاب main.dart به دسته‌بندی سمت سرور
  /// (lib/errorLog.ts) — همه از نوع «کرش برنامه» هستند، پس UI مناسب است.
  static String _categoryFor(String context) => 'UI';

  static String get _platformName {
    if (kIsWeb) return 'web';
    try {
      if (Platform.isAndroid) return 'android';
      if (Platform.isIOS) return 'ios';
      if (Platform.isWindows) return 'windows';
      if (Platform.isMacOS) return 'macos';
      if (Platform.isLinux) return 'linux';
    } catch (_) {
      /* dart:io روی وب در دسترس نیست — kIsWeb بالا این حالت را پوشش می‌دهد */
    }
    return 'unknown';
  }

  static String? get _osVersion {
    if (kIsWeb) return null;
    try {
      return Platform.operatingSystemVersion;
    } catch (_) {
      return null;
    }
  }

  /// ارسال خاموش به سرور — هرگز نباید یک خطای تازه بسازد یا مسیر اصلی
  /// (که خودش از یک کرش می‌آید) را کند/قفل کند.
  static void _reportToBackend(AppErrorEntry entry) {
    unawaited(
      _reportDio
          .post<dynamic>(
            '/errors',
            data: {
              'category': _categoryFor(entry.context),
              'severity': 'high',
              'title': 'کرش برنامه (${entry.context})',
              'message': entry.error,
              'stackTrace': entry.stack.isEmpty ? null : entry.stack,
              'source': 'flutter_app',
              'screenOrEndpoint': entry.context,
              'platform': _platformName,
              'osVersion': _osVersion,
            },
          )
          .then(
            (_) {},
            onError: (Object e) {
              // بی‌صدا — نبودِ اینترنت/در دسترس‌نبودن سرور نباید چیزی را بشکند.
              if (kDebugMode) debugPrint('[AppErrorHandler] گزارش خطا به سرور ناموفق بود: $e');
            },
          ),
    );
  }

  /// «ردِ نان» (breadcrumb) برای مسیرهای پرخطری که به یک SDK/کد بومی
  /// می‌روند (مثل `_jitsiMeet.join()` در ورود به سمینار) — جایی که یک کرش
  /// واقعی ممکن است اصلاً به Dart نرسد و [record] هرگز صدا زده نشود.
  ///
  /// چرا لازم است؟ اگر پردازه دقیقاً همان لحظه از بین برود، تنها راه فهمیدن
  /// «تا کجا رسیدیم» این است که هر قدم را *قبل* از انجامش اینجا ثبت کنیم.
  /// برخلاف [record]، این متد را عمداً await می‌کنیم (نه fire-and-forget)
  /// تا مطمئن شویم درخواست واقعاً قبل از قدم پرخطر بعدی به سرور رسیده —
  /// در غیر این صورت خودِ تأخیر شبکه ممکن بود باعث شود آخرین ردِ نان هم
  /// هرگز ارسال نشود.
  static Future<void> breadcrumb(String message, {String context = 'breadcrumb', String severity = 'low'}) async {
    if (kDebugMode) debugPrint('[Breadcrumb/$context] $message');
    try {
      await _reportDio.post<dynamic>(
        '/errors',
        data: {
          'category': 'UI',
          'severity': severity,
          'title': 'ردیابی: $context',
          'message': message,
          'source': 'flutter_app',
          'screenOrEndpoint': context,
          'platform': _platformName,
          'osVersion': _osVersion,
        },
      ).timeout(const Duration(seconds: 3));
    } catch (e) {
      if (kDebugMode) debugPrint('[AppErrorHandler] ارسال ردِ نان ناموفق بود: $e');
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
