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

/// سرویس پخش زندهٔ سمینار روی Cloudflare Stream.
///
/// مسیرهای سرور:
///   • POST /seminars/:id/go-live  → ساخت/بازیابی Live Input و رفتن به وضعیت live
///   • POST /seminars/:id/end-live → پایان پخش (status = ended)
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
}
