import 'dart:math' as math;

import '../../domain/entities/competition_entities.dart';
import 'competition_data_source.dart';

/// دادهٔ Mock — فقط برای پیش‌نمایش وقتی `kUseLiveBackend = false` (بدون
/// نیاز به سرور). ۵ لیگ/۵۰ عنوان و آستانه‌ها دقیقاً همان طراحی سرور را
/// بازتولید می‌کند (`backend/migrations/0048_competition_v2_tiers_and_quests.sql`)
/// تا نمای محلی با نمای واقعی یکسان به‌نظر برسد.
class CompetitionLocalDataSource implements CompetitionDataSource {
  static const _leagueTitles = <String, List<String>>{
    'emerging_stars': [
      'جستجوگر', 'کاوشگر کنجکاو', 'دانش‌پوی نوپا', 'پرسشگر کوچک', 'آموزندهٔ پرتلاش',
      'پویای علم', 'روشن‌ضمیر', 'ستارهٔ درخشان', 'پیشتاز راه', 'فاتح افق',
    ],
    'pioneers': [
      'روشنگر', 'طلایه‌دار کوچک', 'نوآور', 'راه‌گشای دانش', 'اندیشمند جوان',
      'پژوهندهٔ تازه‌کار', 'خردورز', 'نظریه‌پرداز', 'مبتکر', 'معمار آینده',
    ],
    'scholars': [
      'پژوهشگر', 'دانش‌پژوه', 'ژرف‌اندیش', 'حکیم جوان', 'فرزانهٔ نوخاسته',
      'استاد مباحثه', 'صاحب‌نظر', 'دانای راز', 'پویندهٔ حقیقت', 'کمیاب‌دان',
    ],
    'masters': [
      'استاد منطق', 'چیره‌دست', 'راهبر اندیشه', 'صاحب‌بصیرت', 'فرمانده دانش',
      'معمار خرد', 'پیشوای علم', 'دانای بزرگ', 'حکمران دانایی', 'فرمانروای اندیشه',
    ],
    'legends': [
      'اسطوره', 'نماد دانایی', 'ستون خرد', 'چراغ راه', 'پیشگام جاویدان',
      'قهرمان بی‌بدیل', 'نگین مکتب', 'افسانهٔ زمان', 'جهان‌دان', 'سیمرغ دانش',
    ],
  };

  static const _leagues = [
    (1, 10, 'emerging_stars', 'ستاره‌های نوظهور', 'eco_rounded', '#8A7D6B', '#564A3C', 'آنلاک شدن آواتارهای پایه'),
    (11, 20, 'pioneers', 'طلایه‌داران دانش', 'local_fire_department_rounded', '#6BCB8E', '#1B8A4C', 'فریم‌های رنگی دور پروفایل'),
    (21, 30, 'scholars', 'فرزانگان', 'star_rounded', '#FFE49A', '#E8A800', 'نشان‌های درخشان و افکت صوتی اختصاصی'),
    (31, 40, 'masters', 'فرمانروایان خرد', 'military_tech_rounded', '#8FD3FF', '#3B82C4', 'قابلیت ارسال چالش مستقیم به دیگران'),
    (41, 50, 'legends', 'اسطوره‌های جاویدان', 'workspace_premium_rounded', '#F6A8FF', '#8A3DFF', 'ورود به تالار افتخارات مکتب'),
  ];

  List<RankTier>? _tiersCache;

  List<RankTier> _buildTiers() {
    if (_tiersCache != null) return _tiersCache!;
    final tiers = <RankTier>[];
    for (final league in _leagues) {
      final (start, end, key, leagueTitle, icon, cFrom, cTo, reward) = league;
      final titles = _leagueTitles[key]!;
      for (var n = start; n <= end; n++) {
        final sub = n - start; // 0-based index into titles
        final minPoints = n == 1 ? 0 : (17 * math.pow(n, 2.05)).round();
        final isLast = n == 50;
        tiers.add(RankTier(
          rankNo: n,
          leagueKey: key,
          leagueTitleFa: leagueTitle,
          titleFa: titles[sub],
          icon: isLast ? 'auto_awesome_rounded' : icon,
          colorFrom: isLast ? '#FFD86B' : cFrom,
          colorTo: isLast ? '#8A3DFF' : cTo,
          minPoints: minPoints,
          rewardLabelFa: isLast ? 'مقام سیمرغ دانش — واجد‌شرایط نبرد زنده برای مقام اول (به‌زودی)' : reward,
        ));
      }
    }
    _tiersCache = tiers;
    return tiers;
  }

  RankTier _tierFor(int points) {
    final tiers = _buildTiers();
    var current = tiers.first;
    for (final t in tiers) {
      if (t.minPoints <= points) {
        current = t;
      } else {
        break;
      }
    }
    return current;
  }

  static const _demoTotal = 3200;
  final Set<String> _claimed = {'m_first_lesson', 'm_avatar'};
  final Set<String> _claimedDaily = {};

  @override
  Future<List<RankTier>> getRankTiers() async => _buildTiers();

  @override
  Future<List<LeaderboardEntry>> getLeaderboard({required bool byGrade}) async {
    final names = [
      'مریم احمدی', 'زهرا رضایی', 'فاطمه محمدی', 'سما کریمی', 'نگین یوسفی',
      'ارزو نوری', 'حدیثه صادقی', 'روژان حیدری', 'شبنم رحیمی', 'سارا قاسمی',
    ];
    final rng = math.Random(7);
    final list = <LeaderboardEntry>[];
    var points = 18000;
    for (var i = 0; i < names.length; i++) {
      points -= rng.nextInt(1400) + 500;
      list.add(LeaderboardEntry(
        position: i + 1,
        studentId: 'demo_$i',
        displayName: names[i],
        avatarUrl: null,
        grade: 9,
        totalPoints: math.max(points, 50),
        tier: _tierFor(math.max(points, 50)),
      ));
    }
    return list;
  }

  @override
  Future<CompetitionStatus> getMyStatus() async {
    final tiers = _buildTiers();
    final current = _tierFor(_demoTotal);
    final next = tiers.firstWhere((t) => t.minPoints > _demoTotal, orElse: () => current);
    final hasNext = next.rankNo != current.rankNo;
    return CompetitionStatus(
      totalPoints: _demoTotal,
      tier: current,
      nextTier: hasNext ? next : null,
      pointsToNextTier: hasNext ? next.minPoints - _demoTotal : null,
      progressToNextTierPercent: hasNext
          ? ((_demoTotal - current.minPoints) / (next.minPoints - current.minPoints) * 100).clamp(0, 100).toDouble()
          : 100,
      globalPosition: 4,
      gradePosition: 2,
      pointsToRankOneGlobal: 1450,
      streakCurrent: 5,
      streakLongest: 12,
      missionsCompleted: _claimed.length,
      missionsTotal: 20,
    );
  }

  @override
  Future<List<CompetitionMission>> getMissions() async {
    final defs = [
      ('m_first_lesson', 'curriculum', 'اولین قدم', 'اولین درس خود را ببینید.', 'play_circle_rounded', 1, 10, 1),
      ('m_lessons_10', 'curriculum', 'شاگرد کوشا', '۱۰ درس ببینید.', 'menu_book_rounded', 10, 40, 6),
      ('m_chapter_1', 'curriculum', 'اولین فصل', 'یک فصل را کامل تکمیل کنید.', 'flag_circle_rounded', 1, 25, 1),
      ('m_homework_5', 'homework', 'کارخانگی‌کار', '۵ کارخانگی خود را ارسال کنید.', 'assignment_turned_in_rounded', 5, 60, 2),
      ('m_exam_1', 'exams', 'اولین کامیابی', 'در یک امتحان کامیاب شوید.', 'fact_check_rounded', 1, 40, 0),
      ('m_memory_1', 'community', 'اولین روایت', 'اولین روایت خود را در حافظهٔ جمعی بنویسید.', 'auto_stories_rounded', 1, 15, 1),
      ('m_avatar', 'profile', 'آراستن پروفایل', 'یک عکس پروفایل برای خود انتخاب کنید.', 'account_circle_rounded', 1, 15, 1),
      ('m_chat_10', 'community', 'هم‌صحبت', '۱۰ پیام در چت بفرستید.', 'chat_bubble_rounded', 10, 30, 3),
      ('m_seminar_3', 'seminars', 'اهل مجلس', 'در ۳ سمینار ثبت‌نام کنید.', 'groups_2_rounded', 3, 45, 1),
      ('m_streak_7', 'streak', 'هفتهٔ پیوسته', '۷ روز پیاپی در برنامه فعال باشید.', 'local_fire_department_rounded', 7, 70, 5),
    ];
    return defs.map((d) {
      final (id, cat, title, desc, icon, target, reward, progress) = d;
      return CompetitionMission(
        id: id,
        category: cat,
        titleFa: title,
        descriptionFa: desc,
        icon: icon,
        targetCount: target,
        pointsReward: reward,
        progressCount: math.min(progress, target),
        completed: progress >= target,
        claimed: _claimed.contains(id),
      );
    }).toList();
  }

  @override
  Future<int> claimMission(String missionId) async {
    _claimed.add(missionId);
    return 25;
  }

  @override
  Future<List<DailyQuest>> getDailyQuests() async {
    final defs = [
      ('dq_watch_2_lessons', 'تماشای ۲ درس', 'امروز ۲ درس ببینید.', 'play_circle_rounded', 2, 40, 1, null),
      ('dq_read_1_article', 'مطالعهٔ ۱ مقاله', 'یک مقاله یا خلاصهٔ کتاب در کتابخانه بخوانید.', 'auto_stories_rounded', 1, 30, 1, null),
      ('dq_take_related_quiz', 'آزمون فصل مرتبط', 'بعد از مطالعه، در یک آزمون فصل شرکت کنید.', 'quiz_rounded', 1, 60, 0, 'dq_read_1_article'),
      ('dq_homework_1', 'ارسال کارخانگی', 'یک کارخانگی امروز ارسال کنید.', 'assignment_turned_in_rounded', 1, 35, 0, null),
      ('dq_memory_1', 'روایت روزانه', 'یک روایت در حافظهٔ جمعی به‌اشتراک بگذارید.', 'groups_rounded', 1, 20, 0, null),
    ];
    return defs.map((d) {
      final (id, title, desc, icon, target, reward, progress, requires) = d;
      final requiresClaimed = requires == null || _claimedDaily.contains(requires);
      return DailyQuest(
        id: id,
        titleFa: title,
        descriptionFa: desc,
        icon: icon,
        targetCount: target,
        pointsReward: reward,
        progressCount: math.min(progress, target),
        completed: progress >= target,
        claimed: _claimedDaily.contains(id),
        locked: !requiresClaimed,
        requiresQuestId: requires,
      );
    }).toList();
  }

  @override
  Future<int> claimDailyQuest(String questId) async {
    _claimedDaily.add(questId);
    return 30;
  }

  @override
  Future<CompetitionStats> getStats() async {
    final rng = math.Random(3);
    final series = List.generate(7, (i) {
      final d = DateTime.now().subtract(Duration(days: 6 - i));
      return DailyPointsEntry(date: d.toIso8601String().substring(0, 10), points: 60 + rng.nextInt(220));
    });
    return CompetitionStats(accuracyPercent: 82.5, examsTaken: 12, examsPassed: 10, weeklyPointsSeries: series);
  }
}
