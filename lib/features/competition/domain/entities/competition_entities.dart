import 'package:equatable/equatable.dart';

/// یکی از ۵۰ مقام رقابت — طبق `backend/migrations/0047_competition_system.sql`
/// (جدول `rank_tiers`). داده‌محور است: نام/رنگ/آستانه از سرور می‌آید تا بدون
/// نیاز به آپدیت اپ قابل تنظیم باشد.
class RankTier extends Equatable {
  final int rankNo; // ۱..۵۰
  final String leagueKey; // emerging_stars|pioneers|scholars|masters|legends
  final String leagueTitleFa; // نام لیگ (مثلاً «فرزانگان»)
  final String titleFa;
  final String icon; // نام آیکون متریال — نگاه کن به competition_icons.dart
  final String colorFrom;
  final String colorTo;
  final int minPoints;
  final String rewardLabelFa; // پاداش این لیگ (آواتار/فریم/نشان/چالش/تالار افتخارات)

  const RankTier({
    required this.rankNo,
    required this.leagueKey,
    required this.leagueTitleFa,
    required this.titleFa,
    required this.icon,
    required this.colorFrom,
    required this.colorTo,
    required this.minPoints,
    required this.rewardLabelFa,
  });

  factory RankTier.fromJson(Map<String, dynamic> j) => RankTier(
        rankNo: (j['rankNo'] as num).toInt(),
        leagueKey: j['leagueKey']?.toString() ?? 'emerging_stars',
        leagueTitleFa: j['leagueTitleFa']?.toString() ?? '',
        titleFa: j['titleFa']?.toString() ?? '',
        icon: j['icon']?.toString() ?? 'star_rounded',
        colorFrom: j['colorFrom']?.toString() ?? '#8A7D6B',
        colorTo: j['colorTo']?.toString() ?? '#564A3C',
        minPoints: (j['minPoints'] as num?)?.toInt() ?? 0,
        rewardLabelFa: j['rewardLabelFa']?.toString() ?? '',
      );

  static const empty = RankTier(
    rankNo: 1,
    leagueKey: 'emerging_stars',
    leagueTitleFa: 'ستاره‌های نوظهور',
    titleFa: 'جستجوگر',
    icon: 'eco_rounded',
    colorFrom: '#8A7D6B',
    colorTo: '#564A3C',
    minPoints: 0,
    rewardLabelFa: '',
  );

  @override
  List<Object?> get props => [rankNo, minPoints];
}

/// یک ردیف در جدول رتبه‌بندی سراسری (Top ۵۰).
class LeaderboardEntry extends Equatable {
  final int position; // ۱..۵۰
  final String studentId;
  final String displayName;
  final String? avatarUrl;
  final int? grade;
  final int totalPoints;
  final RankTier tier;

  const LeaderboardEntry({
    required this.position,
    required this.studentId,
    required this.displayName,
    required this.avatarUrl,
    required this.grade,
    required this.totalPoints,
    required this.tier,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        position: (j['position'] as num).toInt(),
        studentId: j['studentId']?.toString() ?? '',
        displayName: j['displayName']?.toString() ?? '',
        avatarUrl: j['avatarUrl']?.toString(),
        grade: (j['grade'] as num?)?.toInt(),
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        tier: RankTier.fromJson(Map<String, dynamic>.from(j['tier'] as Map)),
      );

  @override
  List<Object?> get props => [position, studentId, totalPoints];
}

/// وضعیت رقابتی شاگرد وارد‌شده — طبق `GET /competition/me`.
class CompetitionStatus extends Equatable {
  final int totalPoints;
  final RankTier tier;
  final RankTier? nextTier;
  final int? pointsToNextTier;
  final double progressToNextTierPercent;
  final int globalPosition;
  final int? gradePosition;
  final int? pointsToRankOneGlobal;
  final int streakCurrent;
  final int streakLongest;
  final int missionsCompleted;
  final int missionsTotal;

  const CompetitionStatus({
    required this.totalPoints,
    required this.tier,
    required this.nextTier,
    required this.pointsToNextTier,
    required this.progressToNextTierPercent,
    required this.globalPosition,
    required this.gradePosition,
    required this.pointsToRankOneGlobal,
    required this.streakCurrent,
    required this.streakLongest,
    required this.missionsCompleted,
    required this.missionsTotal,
  });

  bool get isRankOne => globalPosition == 1;

  factory CompetitionStatus.fromJson(Map<String, dynamic> j) => CompetitionStatus(
        totalPoints: (j['totalPoints'] as num?)?.toInt() ?? 0,
        tier: RankTier.fromJson(Map<String, dynamic>.from(j['tier'] as Map)),
        nextTier: j['nextTier'] == null ? null : RankTier.fromJson(Map<String, dynamic>.from(j['nextTier'] as Map)),
        pointsToNextTier: (j['pointsToNextTier'] as num?)?.toInt(),
        progressToNextTierPercent: (j['progressToNextTierPercent'] as num?)?.toDouble() ?? 0,
        globalPosition: (j['globalPosition'] as num?)?.toInt() ?? 0,
        gradePosition: (j['gradePosition'] as num?)?.toInt(),
        pointsToRankOneGlobal: (j['pointsToRankOneGlobal'] as num?)?.toInt(),
        streakCurrent: (j['streak']?['currentStreak'] as num?)?.toInt() ?? 0,
        streakLongest: (j['streak']?['longestStreak'] as num?)?.toInt() ?? 0,
        missionsCompleted: (j['missionsCompleted'] as num?)?.toInt() ?? 0,
        missionsTotal: (j['missionsTotal'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [totalPoints, globalPosition];
}

/// یک میشن (چالش) رقابت — پیشرفت آن از یک بخش واقعی اپ (درس/کارخانگی/
/// امتحان/حافظهٔ جمعی/چت/پروفایل/…) می‌آید. طبق `GET /competition/missions`.
class CompetitionMission extends Equatable {
  final String id;
  final String category;
  final String titleFa;
  final String descriptionFa;
  final String icon;
  final int targetCount;
  final int pointsReward;
  final int progressCount;
  final bool completed;
  final bool claimed;

  const CompetitionMission({
    required this.id,
    required this.category,
    required this.titleFa,
    required this.descriptionFa,
    required this.icon,
    required this.targetCount,
    required this.pointsReward,
    required this.progressCount,
    required this.completed,
    required this.claimed,
  });

  double get progressPercent => targetCount <= 0 ? 1 : (progressCount / targetCount).clamp(0, 1).toDouble();

  /// آماده برای دریافت پاداش (تکمیل شده ولی هنوز دریافت نشده).
  bool get claimable => completed && !claimed;

  factory CompetitionMission.fromJson(Map<String, dynamic> j) => CompetitionMission(
        id: j['id']?.toString() ?? '',
        category: j['category']?.toString() ?? '',
        titleFa: j['titleFa']?.toString() ?? '',
        descriptionFa: j['descriptionFa']?.toString() ?? '',
        icon: j['icon']?.toString() ?? 'star_rounded',
        targetCount: (j['targetCount'] as num?)?.toInt() ?? 1,
        pointsReward: (j['pointsReward'] as num?)?.toInt() ?? 0,
        progressCount: (j['progressCount'] as num?)?.toInt() ?? 0,
        completed: j['completed'] == true,
        claimed: j['claimed'] == true,
      );

  @override
  List<Object?> get props => [id, progressCount, claimed];
}

/// یک میشن روزانه — برخلاف [CompetitionMission] (دستاورد دائمی)، هر روز صفر
/// می‌شود. `locked` یعنی این میشن به‌خاطر قفل زنجیره‌ای (باید اول میشن
/// پیش‌نیاز امروز دریافت شود) هنوز قابل‌دریافت نیست. طبق `GET
/// /competition/daily-quests`.
class DailyQuest extends Equatable {
  final String id;
  final String titleFa;
  final String descriptionFa;
  final String icon;
  final int targetCount;
  final int pointsReward;
  final int progressCount;
  final bool completed;
  final bool claimed;
  final bool locked;
  final String? requiresQuestId;

  const DailyQuest({
    required this.id,
    required this.titleFa,
    required this.descriptionFa,
    required this.icon,
    required this.targetCount,
    required this.pointsReward,
    required this.progressCount,
    required this.completed,
    required this.claimed,
    required this.locked,
    required this.requiresQuestId,
  });

  double get progressPercent => targetCount <= 0 ? 1 : (progressCount / targetCount).clamp(0, 1).toDouble();
  bool get claimable => completed && !claimed && !locked;

  factory DailyQuest.fromJson(Map<String, dynamic> j) => DailyQuest(
        id: j['id']?.toString() ?? '',
        titleFa: j['titleFa']?.toString() ?? '',
        descriptionFa: j['descriptionFa']?.toString() ?? '',
        icon: j['icon']?.toString() ?? 'star_rounded',
        targetCount: (j['targetCount'] as num?)?.toInt() ?? 1,
        pointsReward: (j['pointsReward'] as num?)?.toInt() ?? 0,
        progressCount: (j['progressCount'] as num?)?.toInt() ?? 0,
        completed: j['completed'] == true,
        claimed: j['claimed'] == true,
        locked: j['locked'] == true,
        requiresQuestId: j['requiresQuestId']?.toString(),
      );

  @override
  List<Object?> get props => [id, progressCount, claimed, locked];
}

/// آمار پویا برای «کارت آمار» — دقت پاسخ‌دهی + نمودار هفتگی امتیاز.
class CompetitionStats extends Equatable {
  final double? accuracyPercent;
  final int examsTaken;
  final int examsPassed;
  final List<DailyPointsEntry> weeklyPointsSeries;

  const CompetitionStats({
    required this.accuracyPercent,
    required this.examsTaken,
    required this.examsPassed,
    required this.weeklyPointsSeries,
  });

  factory CompetitionStats.fromJson(Map<String, dynamic> j) => CompetitionStats(
        accuracyPercent: (j['accuracyPercent'] as num?)?.toDouble(),
        examsTaken: (j['examsTaken'] as num?)?.toInt() ?? 0,
        examsPassed: (j['examsPassed'] as num?)?.toInt() ?? 0,
        weeklyPointsSeries: ((j['weeklyPointsSeries'] as List?) ?? [])
            .map((e) => DailyPointsEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );

  @override
  List<Object?> get props => [accuracyPercent, examsTaken, examsPassed];
}

class DailyPointsEntry extends Equatable {
  final String date; // 'YYYY-MM-DD'
  final int points;
  const DailyPointsEntry({required this.date, required this.points});

  factory DailyPointsEntry.fromJson(Map<String, dynamic> j) =>
      DailyPointsEntry(date: j['date']?.toString() ?? '', points: (j['points'] as num?)?.toInt() ?? 0);

  @override
  List<Object?> get props => [date, points];
}
