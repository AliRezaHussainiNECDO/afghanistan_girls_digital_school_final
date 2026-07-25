import '../../../../core/network/api_client.dart';

/// نتیجهٔ شروع پخش زنده — اطلاعاتی که استاد برای پخش (با OBS/Larix) نیاز دارد،
/// به‌علاوهٔ نشانی پخش HLS که شاگردان با آن تماشا می‌کنند.
class GoLiveResult {
  /// شناسهٔ ورودیِ زندهٔ Cloudflare Stream.
  final String streamUid;

  /// نشانی پخش HLS برای شاگردان.
  final String playbackUrl;

  /// نشانی سرور RTMPS (در نرم‌افزار پخش وارد می‌شود).
  final String rtmpsUrl;

  /// کلید پخش RTMPS (محرمانه — فقط به استاد نشان داده می‌شود).
  final String rtmpsKey;

  /// نشانی SRT (اختیاری، برای شبکه‌های پرتأخیر).
  final String srtUrl;

  const GoLiveResult({
    required this.streamUid,
    required this.playbackUrl,
    required this.rtmpsUrl,
    required this.rtmpsKey,
    this.srtUrl = '',
  });
}

/// خطای تایپ‌دار پخش زنده — با کد `STREAM_NOT_CONFIGURED` می‌توان تشخیص داد که
/// سرور هنوز Cloudflare Stream را ندارد و باید به لینک دستی برگشت.
class LiveStreamException implements Exception {
  final String message;
  final String? code;
  const LiveStreamException(this.message, {this.code});

  bool get isNotConfigured => code == 'STREAM_NOT_CONFIGURED';

  @override
  String toString() => 'LiveStreamException($code, $message)';
}

/// نتیجهٔ درخواست توکن ویدیوکنفرانس (JaaS) برای اتاق داخلی سمینار.
///
/// اگر [configured] نادرست باشد یعنی سرور هنوز JaaS را تنظیم نکرده — در این
/// حالت اتاق باید (به‌طور فال‌بک، نه شکست) بدون `serverURL`/`token` به سرور
/// عمومی پیش‌فرض Jitsi وصل شود، دقیقاً مثل رفتار قبلی.
class SeminarVideoToken {
  final bool configured;
  final String appId;
  final String room;
  final String serverUrl;
  final String token;
  final bool isHost;

  const SeminarVideoToken({
    required this.configured,
    this.appId = '',
    this.room = '',
    this.serverUrl = '',
    this.token = '',
    this.isHost = false,
  });

  factory SeminarVideoToken.notConfigured({bool isHost = false}) =>
      SeminarVideoToken(configured: false, isHost: isHost);
}

/// سرویس پخش زندهٔ سمینار روی Cloudflare Stream.
///
/// مسیرهای سرور:
///   • POST /seminars/:id/go-live     → ساخت/بازیابی Live Input و رفتن به وضعیت live
///   • POST /seminars/:id/end-live    → پایان پخش (status = ended)
///   • GET  /seminars/:id/video-token → توکن JWT برای اتاق ویدیوکنفرانس واقعی (JaaS)
class SeminarLiveService {
  final ApiClient _api;
  const SeminarLiveService(this._api);

  /// شروع پخش زنده توسط استاد/مدیر.
  Future<GoLiveResult> goLive(String seminarId) async {
    try {
      final data = await _api.post('/seminars/$seminarId/go-live');
      final m = (data as Map);
      return GoLiveResult(
        streamUid: m['streamUid']?.toString() ?? '',
        playbackUrl: m['playbackUrl']?.toString() ?? '',
        rtmpsUrl: m['rtmpsUrl']?.toString() ?? '',
        rtmpsKey: m['rtmpsKey']?.toString() ?? '',
        srtUrl: m['srtUrl']?.toString() ?? '',
      );
    } on ApiException catch (e) {
      throw LiveStreamException(e.message, code: e.code);
    }
  }

  /// پایان پخش زنده.
  Future<void> endLive(String seminarId) async {
    try {
      await _api.post('/seminars/$seminarId/end-live');
    } on ApiException catch (e) {
      throw LiveStreamException(e.message, code: e.code);
    }
  }

  /// توکن اتاق ویدیوکنفرانس واقعی (JaaS) — رفع اشکال ریشه‌ای «اتاق سمینار
  /// قابل‌اتکا نیست»: اگر سرور JaaS را تنظیم کرده باشد، یک JWT کوتاه‌مدت و
  /// محدود به همین سمینار/کاربر برمی‌گرداند؛ در غیر این صورت (یا هر خطای
  /// شبکه) به‌جای شکستن جریان پیوستن، «تنظیم‌نشده» برمی‌گرداند تا صفحهٔ اتاق
  /// با رفتار قبلی (سرور عمومی، بدون توکن) ادامه دهد — پیوستن به کلاس هرگز
  /// نباید فقط به‌خاطر این توکن اختیاری متوقف شود.
  Future<SeminarVideoToken> fetchVideoToken(String seminarId) async {
    try {
      final data = await _api.get('/seminars/$seminarId/video-token');
      final m = (data as Map);
      final configured = m['configured'] == true;
      if (!configured) return const SeminarVideoToken(configured: false);
      return SeminarVideoToken(
        configured: true,
        appId: m['appId']?.toString() ?? '',
        room: m['room']?.toString() ?? '',
        serverUrl: m['serverUrl']?.toString() ?? '',
        token: m['token']?.toString() ?? '',
        isHost: m['isHost'] == true,
      );
    } catch (_) {
      return const SeminarVideoToken(configured: false);
    }
  }
}
