import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/network_providers.dart';
import '../../data/datasources/admin_live_arena_remote_datasource.dart';
import '../../domain/entities/arena_event_list_item.dart';

final adminLiveArenaDataSourceProvider = Provider<AdminLiveArenaRemoteDataSource>(
  (ref) => AdminLiveArenaRemoteDataSource(ref.watch(apiClientProvider)),
);

/// فهرست رویدادها (جاری/بعدی + تاریخچه) + شمار بانک سؤال — بعد از هر
/// زمان‌بندی/لغو با [AdminLiveArenaActions] دوباره بارگذاری می‌شود.
final adminLiveArenaEventsProvider = FutureProvider.autoDispose<AdminArenaEventsPage>((ref) async {
  final ds = ref.watch(adminLiveArenaDataSourceProvider);
  return ds.fetchEvents();
});

class AdminLiveArenaActions {
  final Ref ref;
  const AdminLiveArenaActions(this.ref);

  Future<String> schedule({
    required DateTime startsAt,
    String? titleFa,
    int? durationMinutes,
    required int minRankNo,
    required int questionCount,
    required int timeLimitSeconds,
  }) async {
    final id = await ref.read(adminLiveArenaDataSourceProvider).schedule(
          startsAt: startsAt,
          titleFa: titleFa,
          durationMinutes: durationMinutes,
          minRankNo: minRankNo,
          questionCount: questionCount,
          timeLimitSeconds: timeLimitSeconds,
        );
    ref.invalidate(adminLiveArenaEventsProvider);
    return id;
  }

  Future<void> cancel(String eventId) async {
    await ref.read(adminLiveArenaDataSourceProvider).cancel(eventId);
    ref.invalidate(adminLiveArenaEventsProvider);
  }
}

final adminLiveArenaActionsProvider = Provider((ref) => AdminLiveArenaActions(ref));
