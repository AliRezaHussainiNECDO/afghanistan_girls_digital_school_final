import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/network_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart' show kUseLiveBackend;
import '../../data/datasources/competition_data_source.dart';
import '../../data/datasources/competition_local_datasource.dart';
import '../../data/datasources/competition_remote_datasource.dart';
import '../../domain/entities/competition_entities.dart';

/// محلی (پیش‌نمایش) یا Backend واقعی — طبق سوییچ `kUseLiveBackend`.
final competitionDataSourceProvider = Provider<CompetitionDataSource>((ref) {
  if (kUseLiveBackend) {
    return CompetitionRemoteDataSource(ref.watch(apiClientProvider));
  }
  return CompetitionLocalDataSource();
});

/// با تغییر این مقدار، وضعیت/میشن‌های رقابت دوباره از سرور خوانده می‌شوند —
/// بعد از دریافت پاداش یک میشن صدا زده می‌شود تا فوراً تازه شود.
final competitionRefreshProvider = StateProvider<int>((ref) => 0);

/// فهرست کامل ۵۰ مقام — تقریباً هرگز تغییر نمی‌کند، پس فقط یک‌بار در طول
/// عمر Provider خوانده می‌شود (بدون وابستگی به refreshProvider).
final rankTiersProvider = FutureProvider<List<RankTier>>(
  (ref) => ref.read(competitionDataSourceProvider).getRankTiers(),
);

/// scope=false → سراسری، scope=true → فقط هم‌صنفی‌ها.
final leaderboardProvider = FutureProvider.family<List<LeaderboardEntry>, bool>((ref, byGrade) async {
  ref.watch(competitionRefreshProvider);
  return ref.read(competitionDataSourceProvider).getLeaderboard(byGrade: byGrade);
});

final myCompetitionStatusProvider = FutureProvider<CompetitionStatus>((ref) async {
  ref.watch(competitionRefreshProvider);
  return ref.read(competitionDataSourceProvider).getMyStatus();
});

final competitionMissionsProvider = FutureProvider<List<CompetitionMission>>((ref) async {
  ref.watch(competitionRefreshProvider);
  return ref.read(competitionDataSourceProvider).getMissions();
});

/// میشن‌های روزانه — جدا از [competitionMissionsProvider] (که دستاوردهای
/// دائمی است)، همین امروز صفر می‌شود.
final dailyQuestsProvider = FutureProvider<List<DailyQuest>>((ref) async {
  ref.watch(competitionRefreshProvider);
  return ref.read(competitionDataSourceProvider).getDailyQuests();
});

/// کارت آمار پویا (دقت پاسخ‌دهی + نمودار هفتگی امتیاز).
final competitionStatsProvider = FutureProvider<CompetitionStats>((ref) async {
  ref.watch(competitionRefreshProvider);
  return ref.read(competitionDataSourceProvider).getStats();
});

/// نتیجهٔ آخرین دریافت پاداش — برای نمایش انیمیشن «+N امتیاز» یک‌بار مصرف.
final lastClaimedPointsProvider = StateProvider<int?>((ref) => null);

class CompetitionActions {
  final Ref ref;
  CompetitionActions(this.ref);

  Future<int> claimMission(String missionId) async {
    final points = await ref.read(competitionDataSourceProvider).claimMission(missionId);
    ref.read(lastClaimedPointsProvider.notifier).state = points;
    ref.read(competitionRefreshProvider.notifier).state++;
    return points;
  }

  Future<int> claimDailyQuest(String questId) async {
    final points = await ref.read(competitionDataSourceProvider).claimDailyQuest(questId);
    ref.read(lastClaimedPointsProvider.notifier).state = points;
    ref.read(competitionRefreshProvider.notifier).state++;
    return points;
  }
}

final competitionActionsProvider = Provider((ref) => CompetitionActions(ref));
