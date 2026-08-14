import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../../core/network/api_client.dart';

/// اتصال زندهٔ یک اتاق آرنا — Wrapper نازک روی `web_socket_channel` (که روی
/// موبایل/دسکتاپ/وب یکسان کار می‌کند، برخلاف `dart:io.WebSocket` که در وب
/// موجود نیست). فقط JSON encode/decode می‌کند؛ منطق فاز/جدول امتیاز در
/// `LiveArenaController` (لایهٔ presentation) است — این کلاس معماری تمیز را
/// حفظ می‌کند (`data/` فقط انتقال داده، نه منطق).
class LiveArenaSocketDataSource {
  final WebSocketChannel _channel;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription? _sub;

  LiveArenaSocketDataSource._(this._channel) {
    _sub = _channel.stream.listen(
      (raw) {
        try {
          final decoded = jsonDecode(raw as String) as Map<String, dynamic>;
          _controller.add(decoded);
        } catch (_) {
          // پیام غیرمنتظره — نادیده گرفته می‌شود، اتصال زنده می‌ماند
        }
      },
      onError: (Object err) => _controller.addError(err),
      onDone: () => _controller.close(),
    );
  }

  /// `eventId` — کدام اتاق. `token` — Access Token فعلی (چون WebSocket در
  /// مرورگر امکان ست‌کردن هدر `Authorization` را ندارد؛ همان الگوی
  /// `routes/liveArena.ts` سمت سرور: توکن از querystring خوانده می‌شود).
  factory LiveArenaSocketDataSource.connect({required String eventId, required String token}) {
    final httpBase = Uri.parse(kApiBaseUrl);
    final wsScheme = httpBase.scheme == 'https' ? 'wss' : 'ws';
    final uri = Uri(
      scheme: wsScheme,
      host: httpBase.host,
      port: httpBase.hasPort ? httpBase.port : null,
      path: '${httpBase.path}/live-arena/$eventId/socket',
      queryParameters: {'token': token},
    );
    return LiveArenaSocketDataSource._(WebSocketChannel.connect(uri));
  }

  Stream<Map<String, dynamic>> get messages => _controller.stream;

  void sendAnswer(int choiceIndex) {
    _channel.sink.add(jsonEncode({'type': 'answer', 'choiceIndex': choiceIndex}));
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _controller.close();
    await _channel.sink.close();
  }
}
