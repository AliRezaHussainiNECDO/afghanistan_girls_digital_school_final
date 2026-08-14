import '../../domain/entities/competition_entities.dart';

/// قرارداد مشترک DataSource رقابت — نسخهٔ ریموت (Backend واقعی) و محلی
/// (پیش‌نمایش/توسعه، `kUseLiveBackend == false`) هر دو آن را پیاده می‌کنند.
abstract class CompetitionDataSource {
  Future<List<RankTier>> getRankTiers();
  Future<List<LeaderboardEntry>> getLeaderboard({required bool byGrade});
  Future<CompetitionStatus> getMyStatus();
  Future<List<CompetitionMission>> getMissions();

  /// دریافت پاداش یک میشن تکمیل‌شده — امتیاز اهدا‌شده را برمی‌گرداند (برای
  /// نمایش انیمیشن «+N امتیاز»).
  Future<int> claimMission(String missionId);

  Future<List<DailyQuest>> getDailyQuests();
  Future<int> claimDailyQuest(String questId);
  Future<CompetitionStats> getStats();
}
