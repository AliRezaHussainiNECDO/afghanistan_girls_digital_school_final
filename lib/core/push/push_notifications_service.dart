/// Push Notification واقعی روی گوشی (حتی وقتی اپ کاملاً بسته است) — از طریق
/// Firebase Cloud Messaging (FCM). این سرویس فرق دارد با زنگ اعلان (🔔) که
/// از قبل در اپ هست: آن فقط «داخل‌اپی» است (باید اپ را باز کنید تا ببینید)،
/// این‌جا واقعاً یک نوتیفیکیشن سیستم‌عامل است.
///
/// کاملاً اختیاری و Fail-safe: تا وقتی پروژهٔ Firebase به این اپ وصل نشده
/// (یعنی `android/app/google-services.json` و `ios/Runner/GoogleService-Info.plist`
/// هنوز اضافه نشده‌اند — این دو فایل باید از کنسول Firebase توسط خودِ شما
/// دانلود و در همان مسیرها گذاشته شوند)، هر تابع این فایل فقط بی‌صدا هیچ کاری
/// نمی‌کند؛ هیچ‌جای دیگر اپ (ورود/ثبت‌نام/خروج) تحت تأثیر قرار نمی‌گیرد یا
/// کند/خراب نمی‌شود.
library;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../network/network_providers.dart';

/// این تابع باید top-level (نه داخل کلاس) بماند و دقیقاً همین امضا را داشته
/// باشد — فایربیس آن را در یک Isolate کاملاً جدا صدا می‌زند وقتی پیامی
/// می‌رسد و اپ در پس‌زمینه/بسته است. چون Payload سرور همیشه فیلد
/// `notification` دارد (نه فقط `data`)، خودِ سیستم‌عامل بنر را نشان می‌دهد؛
/// اینجا فقط باید مطمئن شویم Firebase در همان Isolate جدا هم initialize
/// شده (وگرنه اگر بعداً کد دیگری در همین Isolate به Firebase نیاز داشت خطا
/// می‌داد).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // پروژهٔ Firebase هنوز وصل نشده — بی‌اثر نادیده گرفته می‌شود.
  }
}

class PushNotificationsService {
  final ApiClient _api;
  PushNotificationsService(this._api);

  static bool _firebaseReady = false;
  static bool _initAttempted = false;

  /// مطمئن می‌شود Firebase initialize شده — اگر `main.dart` از قبل این کار
  /// را انجام داده باشد (حالت عادی)، دوباره صدایش نمی‌زند (`Firebase.apps`
  /// را چک می‌کند) تا خطر خطای «duplicate app» را نداشته باشیم. اگر پروژهٔ
  /// Firebase اصلاً وصل نباشد (فایل‌های پیکربندی بومی موجود نیستند)،
  /// Exception را می‌بلعد و `false` برمی‌گرداند.
  Future<bool> _ensureFirebaseInitialized() async {
    if (_initAttempted) return _firebaseReady;
    _initAttempted = true;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseReady = true;
    } catch (e) {
      debugPrint('[push] Firebase not configured yet — push notifications disabled ($e)');
      _firebaseReady = false;
    }
    return _firebaseReady;
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  /// اجازهٔ اعلان می‌گیرد، توکن دستگاه را می‌گیرد و با حساب کاربر *واردشدهٔ
  /// فعلی* روی سرور پیوند می‌زند (`POST /devices/register`). بعد از هر ورود
  /// موفق (login/ثبت‌نام/بازیابی خودکار نشست) صدا زده می‌شود — نه زودتر، چون
  /// سرور برای ثبت توکن به Bearer Token نیاز دارد.
  Future<void> registerCurrentDevice() async {
    if (!await _ensureFirebaseInitialized()) return;
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return;
      await _api.post('/devices/register', data: {'token': token, 'platform': _platformName()});

      // اگر توکن بعداً عوض شود (نصب تازه/پاک‌شدن دادهٔ اپ)، دوباره ثبت شود.
      messaging.onTokenRefresh.listen((newToken) {
        _api.post('/devices/register', data: {'token': newToken, 'platform': _platformName()}).catchError((_) {});
      });
    } catch (e) {
      debugPrint('[push] registerCurrentDevice failed — $e');
    }
  }

  /// موقع خروج از حساب صدا زده می‌شود تا این دستگاه دیگر برای این کاربر Push
  /// نگیرد (مثلاً اگر گوشی مشترک بین چند شاگرد باشد).
  Future<void> unregisterCurrentDevice() async {
    if (!_firebaseReady) return;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _api.post('/devices/unregister', data: {'token': token});
    } catch (e) {
      debugPrint('[push] unregisterCurrentDevice failed — $e');
    }
  }
}

final pushNotificationsServiceProvider = Provider<PushNotificationsService>(
  (ref) => PushNotificationsService(ref.watch(apiClientProvider)),
);
