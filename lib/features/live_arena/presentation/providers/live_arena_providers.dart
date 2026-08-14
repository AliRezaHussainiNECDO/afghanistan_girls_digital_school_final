import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../data/datasources/live_arena_socket_datasource.dart';
import '../../domain/entities/live_arena_entities.dart';

/// اطلاعات رویداد جاری/بعدیِ آرنا + واجد‌شرایطی من — برای بنر «آرنای زنده»
/// در صفحهٔ رقابت و صفحهٔ اتاق انتظار. با [competitionRefreshProvider] هم‌سو
/// نیست چون آرنا چرخهٔ تازه‌سازی خودش را دارد (خیلی کمتر تغییر می‌کند).
final liveArenaCurrentProvider = FutureProvider<ArenaCurrentInfo>((ref) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/live-arena/current');
  return ArenaCurrentInfo.fromJson(Map<String, dynamic>.from(data as Map));
});

/// نتایج نهاییِ یک رویداد پایان‌یافته (برای دیرآمده‌ها / صفحهٔ نتایج).
final arenaResultsProvider = FutureProvider.family<List<ArenaStanding>, String>((ref, eventId) async {
  final api = ref.watch(apiClientProvider);
  final data = await api.get('/live-arena/$eventId/results');
  final list = (data['standings'] as List? ?? []);
  return list.map((e) => ArenaStanding.fromJson(Map<String, dynamic>.from(e as Map))).toList();
});

enum ArenaConnectionStatus { connecting, connected, disconnected, error }

class LiveArenaRoomState {
  final ArenaConnectionStatus connectionStatus;
  final ArenaRoomSnapshot? snapshot;
  final ArenaAnswerAck? lastAck;
  final String? errorMessage;

  const LiveArenaRoomState({
    required this.connectionStatus,
    this.snapshot,
    this.lastAck,
    this.errorMessage,
  });

  LiveArenaRoomState copyWith({
    ArenaConnectionStatus? connectionStatus,
    ArenaRoomSnapshot? snapshot,
    ArenaAnswerAck? lastAck,
    String? errorMessage,
  }) {
    return LiveArenaRoomState(
      connectionStatus: connectionStatus ?? this.connectionStatus,
      snapshot: snapshot ?? this.snapshot,
      lastAck: lastAck ?? this.lastAck,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  static const initial = LiveArenaRoomState(connectionStatus: ArenaConnectionStatus.connecting);
}

/// کنترلر یک اتاق آرنا — یک اتصال WebSocket زنده به‌ازای هر `eventId`. با
/// `autoDispose` بسته می‌شود وقتی هیچ ویجتی دیگر آن را نمی‌بیند (خروج از
/// صفحهٔ آرنا)، تا اتصال بی‌مورد باز نماند.
class LiveArenaController extends StateNotifier<LiveArenaRoomState> {
  LiveArenaSocketDataSource? _ds;
  StreamSubscription? _sub;
  final String eventId;
  final String Function() tokenProvider;
  int _retryCount = 0;
  Timer? _retryTimer;

  LiveArenaController({required this.eventId, required this.tokenProvider}) : super(LiveArenaRoomState.initial) {
    _connect();
  }

  void _connect() {
    final token = tokenProvider();
    if (token.isEmpty) {
      state = state.copyWith(connectionStatus: ArenaConnectionStatus.error, errorMessage: 'no-token');
      return;
    }
    state = state.copyWith(connectionStatus: ArenaConnectionStatus.connecting);
    try {
      _ds = LiveArenaSocketDataSource.connect(eventId: eventId, token: token);
      _sub = _ds!.messages.listen(_onMessage, onError: (_) => _scheduleReconnect(), onDone: _scheduleReconnect);
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(Map<String, dynamic> msg) {
    _retryCount = 0;
    switch (msg['type']) {
      case 'snapshot':
        state = state.copyWith(connectionStatus: ArenaConnectionStatus.connected, snapshot: ArenaRoomSnapshot.fromJson(msg));
        break;
      case 'answerAck':
        state = state.copyWith(lastAck: ArenaAnswerAck.fromJson(msg));
        break;
      default:
        break; // presence و بقیه — فعلاً فقط برای اطلاع، تأثیری در UI فعلی ندارند
    }
  }

  /// اتصال دوباره با فاصلهٔ فزاینده (تا حداکثر ۵ بار) — قطعی موقت شبکه نباید
  /// شاگرد را از وسط مسابقهٔ زنده کامل بیندازد بیرون.
  void _scheduleReconnect() {
    if (!mounted) return;
    state = state.copyWith(connectionStatus: ArenaConnectionStatus.disconnected);
    if (_retryCount >= 5) return;
    _retryCount++;
    _retryTimer?.cancel();
    _retryTimer = Timer(Duration(seconds: _retryCount * 2), () {
      if (mounted) _connect();
    });
  }

  void answer(int choiceIndex) => _ds?.sendAnswer(choiceIndex);

  @override
  void dispose() {
    _retryTimer?.cancel();
    _sub?.cancel();
    _ds?.dispose();
    super.dispose();
  }
}

final liveArenaControllerProvider =
    StateNotifierProvider.autoDispose.family<LiveArenaController, LiveArenaRoomState, String>((ref, eventId) {
  final tokens = ref.watch(tokenStoreProvider);
  return LiveArenaController(eventId: eventId, tokenProvider: () => tokens.accessToken ?? '');
});
