import '../../../../core/network/api_client.dart';
import '../../domain/entities/competition_entities.dart';
import 'competition_data_source.dart';

/// پیاده‌سازی واقعی — روتر `competition` زیر `/api/v1`
/// (`backend/src/routes/competition.ts`).
class CompetitionRemoteDataSource implements CompetitionDataSource {
  final ApiClient _api;
  CompetitionRemoteDataSource(this._api);

  @override
  Future<List<RankTier>> getRankTiers() async {
    final data = await _api.get('/competition/rank-tiers');
    final list = (data['tiers'] as List? ?? []);
    return list.map((e) => RankTier.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({required bool byGrade}) async {
    final data = await _api.get('/competition/leaderboard', queryParameters: {
      'scope': byGrade ? 'grade' : 'global',
    });
    final list = (data['entries'] as List? ?? []);
    return list.map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<CompetitionStatus> getMyStatus() async {
    final data = await _api.get('/competition/me');
    return CompetitionStatus.fromJson(Map<String, dynamic>.from(data as Map));
  }

  @override
  Future<List<CompetitionMission>> getMissions() async {
    final data = await _api.get('/competition/missions');
    final list = (data['missions'] as List? ?? []);
    return list.map((e) => CompetitionMission.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<int> claimMission(String missionId) async {
    final data = await _api.post('/competition/missions/$missionId/claim');
    return (data['pointsAwarded'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<DailyQuest>> getDailyQuests() async {
    final data = await _api.get('/competition/daily-quests');
    final list = (data['quests'] as List? ?? []);
    return list.map((e) => DailyQuest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  @override
  Future<int> claimDailyQuest(String questId) async {
    final data = await _api.post('/competition/daily-quests/$questId/claim');
    return (data['pointsAwarded'] as num?)?.toInt() ?? 0;
  }

  @override
  Future<CompetitionStats> getStats() async {
    final data = await _api.get('/competition/stats');
    return CompetitionStats.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
