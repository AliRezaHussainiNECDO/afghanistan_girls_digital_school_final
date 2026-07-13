import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'core/errors/app_error_handler.dart';

/// نقطهٔ ورود اپ.
///
/// تمام اجرا داخل یک `runZonedGuarded` قرار می‌گیرد و همهٔ مسیرهای خطای
/// Flutter/Dart به یک مدیریت‌کنندهٔ مرکزی هدایت می‌شوند. هدف: هیچ خطای
/// مدیریت‌نشده‌ای نباید باعث بسته‌شدن ناگهانی برنامه در ایمولاتور/دستگاه شود
/// (مشکل «برنامه بعد از چند دقیقه بسته می‌شود»). به‌جای Crash، خطا ثبت شده و
/// در صورت لزوم یک صفحهٔ دوستانه نمایش داده می‌شود.
void main() {
  runZonedGuarded<void>(
    () {
      WidgetsFlutterBinding.ensureInitialized();

      // ۱) خطاهای فریم‌ورک Flutter (خطای build/layout/paint ویجت‌ها).
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        AppErrorHandler.record(details.exception, details.stack, context: 'FlutterError');
      };

      // ۲) خطاهای همگام/ناهمگامِ لایهٔ موتور که به Dart می‌رسند
      //    (مثلاً خطای پلتفرم، آیزوله). true یعنی «مدیریت شد؛ Crash نکن».
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        AppErrorHandler.record(error, stack, context: 'PlatformDispatcher');
        return true;
      };

      // ۳) به‌جای صفحهٔ قرمز/خاکستری پیش‌فرض، یک کارت خطای آرام نشان بده تا
      //    یک ویجتِ خراب کلِ صفحه را از کار نیندازد.
      ErrorWidget.builder = (FlutterErrorDetails details) => FriendlyErrorWidget(details: details);

      runApp(const ProviderScope(child: App()));
    },
    // ۴) هر خطای مدیریت‌نشدهٔ ناهمگام (Future بدون catch، Timer و …).
    (Object error, StackTrace stack) {
      AppErrorHandler.record(error, stack, context: 'ZoneGuard');
    },
  );
}
