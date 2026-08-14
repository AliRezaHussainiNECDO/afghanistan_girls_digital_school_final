/**
 * lib/competition.ts — «رقابت مکتب» (نسخهٔ ۲ اپ): ۵۰ مقام + جدول رتبه‌بندی
 * سراسری + میشن‌ها. روی زیرساخت امتیازدهی موجود (lib/progress.ts، migration
 * 0018) و جدول‌های تازهٔ migration 0047 ساخته شده — هیچ منطق قبلی تغییر
 * نمی‌کند، فقط لایهٔ رقابت روی همان «دفتر کل امتیازات» اضافه می‌شود.
 *
 * چرا هر بخش اپ اینجا اثر دارد؟ هر فعالیت مثبت (دیدن درس، کارخانگی، امتحان،
 * آزمون فصل، امتحان فاینل، روایت در حافظهٔ جمعی، پیام در چت، تکمیل پروفایل،
 * پاسخ درست به معلم هوشمند، ثبت‌نام سمینار، ورود با کد دعوت، گواهی‌نامه) یک
 * `reason` در student_points_ledger ثبت می‌کند؛ همان امتیاز هم مجموع رقابت را
 * بالا می‌برد و هم پیشرفت میشن مرتبط را — یعنی برای بالا رفتن در رقابت، شاگرد
 * باید واقعاً از تمام بخش‌های برنامه استفاده کند.
 */
import { awardPoints, getStreakStatus } from './progress';

/** مقادیر امتیاز فعالیت‌های تازهٔ متصل‌شده به رقابت (بخش‌هایی که قبل از
 * migration 0047 اصلاً امتیاز نمی‌دادند). مقادیر امتیازدهی قدیمی‌تر
 * (lesson_view/chapter_complete/homework_graded/ai_teacher_correct_answer)
 * دست‌نخورده در همان فایل‌های قبلی (progress.ts/ai.ts) باقی می‌مانند.
 */
export const COMPETITION_POINTS = {
  // امتحان: نمرهٔ قبولی = پایه؛ نمرهٔ کامل (۱۰۰٪) و پاسخ‌دهی سریع هرکدام
  // یک پاداش اضافه و مستقل می‌دهند (هر دو قابل جمع‌شدن با هم).
  examPass: 100,
  examPerfectScoreBonus: 50,
  examSpeedBonus: 50,
  // بودجهٔ زمانی «سریع» — اگر شاگرد در کمتر از نصفِ این بودجه (به ثانیه به
  // ازای هر سؤال) امتحان را تحویل دهد و هم قبول شده باشد، پاداش سرعت می‌گیرد.
  examSpeedSecondsPerQuestion: 60,
  chapterQuizPass: 40,
  // پاداش «مطالعه→آزمون بلافاصله» — اگر آزمون فصل در همان بازهٔ کوتاه بعد از
  // تکمیل فصل داده شود (طبق سند: پاسخ‌دهی بلافاصله به سوالات درس).
  chapterQuizEarlyBonusPercent: 10,
  chapterQuizEarlyWindowMinutes: 30,
  finalExamPass: 400,
  memoryPost: 15,
  memoryPostDailyCap: 3,
  avatarSet: 15,
  chatMessage: 3,
  chatMessageDailyCap: 10,
  inviteWelcome: 10,
  seminarRegistered: 25,
  certificateEarned: 60,
  // کتابخانهٔ دیجیتال — طبق سند اقتصاد امتیاز (۳۰XP، حداکثر ۲ بار در روز).
  libraryRead: 30,
  libraryReadDailyCap: 2,
} as const;

/** شمارش ردیف‌های امروز با یک reason مشخص — برای سقف روزانهٔ ضدِ اسپم
 * (حافظهٔ جمعی/چت) بدون نیاز به جدول جداگانه. */
async function countTodayByReason(db: D1Database, studentId: string, reason: string): Promise<number> {
  const row = await db
    .prepare(
      "SELECT COUNT(*) AS n FROM student_points_ledger WHERE student_id = ? AND reason = ? AND date(created_at) = date('now')",
    )
    .bind(studentId, reason)
    .first<{ n: number }>();
  return row?.n ?? 0;
}

/** آیا این شاگرد قبلاً حداقل یک‌بار برای این reason امتیاز گرفته؟ (پاداش
 * یک‌باره، مثل «تکمیل پروفایل» یا «خوش‌آمدگویی کد دعوت».) */
async function hasEverEarned(db: D1Database, studentId: string, reason: string): Promise<boolean> {
  const row = await db
    .prepare('SELECT 1 FROM student_points_ledger WHERE student_id = ? AND reason = ? LIMIT 1')
    .bind(studentId, reason)
    .first();
  return !!row;
}

/** پاداش یک‌بارهٔ فعالیت — اگر قبلاً گرفته باشد، کاری نمی‌کند (fail-safe،
 * هرگز استثنا پرتاب نمی‌کند تا مسیر اصلی درخواست هرگز نشکند). */
export async function awardOnce(db: D1Database, studentId: string, points: number, reason: string, refId: string): Promise<void> {
  try {
    if (await hasEverEarned(db, studentId, reason)) return;
    await awardPoints(db, studentId, points, reason, refId);
  } catch (err) {
    console.error(`[awardOnce:${reason}] fail-safe —`, err);
  }
}

/** پاداش با سقف روزانه (ضدِ اسپم) — اگر امروز به سقف رسیده، کاری نمی‌کند.
 * fail-safe: هرگز استثنا پرتاب نمی‌کند. */
export async function awardWithDailyCap(
  db: D1Database,
  studentId: string,
  points: number,
  reason: string,
  refId: string,
  dailyCap: number,
): Promise<void> {
  try {
    const todayCount = await countTodayByReason(db, studentId, reason);
    if (todayCount >= dailyCap) return;
    await awardPoints(db, studentId, points, reason, refId);
  } catch (err) {
    console.error(`[awardWithDailyCap:${reason}] fail-safe —`, err);
  }
}

/** پاداش سادهٔ بدون محدودیت (مثلاً امتحان/آزمون که خودشان قبلاً «یک‌بار
 * مجاز» را در سطح دیتابیس تضمین می‌کنند) — fail-safe. */
export async function awardSafe(db: D1Database, studentId: string, points: number, reason: string, refId: string): Promise<void> {
  try {
    await awardPoints(db, studentId, points, reason, refId);
  } catch (err) {
    console.error(`[awardSafe:${reason}] fail-safe —`, err);
  }
}

// ═════════════════════════════ مقام‌ها (Rank Tiers) ═════════════════════════

export type RankTier = {
  rankNo: number;
  leagueKey: string;
  leagueTitleFa: string;
  titleFa: string;
  icon: string;
  colorFrom: string;
  colorTo: string;
  minPoints: number;
  rewardLabelFa: string;
};

let _tierCache: RankTier[] | null = null;

/** فهرست کامل ۵۰ مقام — از دیتابیس خوانده می‌شود (نه هاردکد) تا در آینده
 * بدون تغییر کد قابل تنظیم باشد (migration 0048: ۵ لیگ نام‌گذاری‌شده + پاداش
 * هر لیگ). یک‌بار در طول عمر Worker کش می‌شود (داده‌ای که عملاً هرگز در حین
 * اجرا تغییر نمی‌کند). */
export async function getRankTiers(db: D1Database): Promise<RankTier[]> {
  if (_tierCache) return _tierCache;
  const { results } = await db
    .prepare(
      'SELECT rank_no, league_key, league_title_fa, title_fa, icon, color_from, color_to, min_points, reward_label_fa FROM rank_tiers ORDER BY rank_no',
    )
    .all<{
      rank_no: number;
      league_key: string;
      league_title_fa: string;
      title_fa: string;
      icon: string;
      color_from: string;
      color_to: string;
      min_points: number;
      reward_label_fa: string;
    }>();
  const tiers = results.map((r) => ({
    rankNo: r.rank_no,
    leagueKey: r.league_key,
    leagueTitleFa: r.league_title_fa,
    titleFa: r.title_fa,
    icon: r.icon,
    colorFrom: r.color_from,
    colorTo: r.color_to,
    minPoints: r.min_points,
    rewardLabelFa: r.reward_label_fa,
  }));
  _tierCache = tiers;
  return tiers;
}

export function tierForPoints(tiers: RankTier[], totalPoints: number): { current: RankTier; next: RankTier | null } {
  let current = tiers[0];
  let next: RankTier | null = null;
  for (const t of tiers) {
    if (t.minPoints <= totalPoints) current = t;
    else {
      next = t;
      break;
    }
  }
  return { current, next };
}

// ══════════════════════════ جدول رتبه‌بندی سراسری ═══════════════════════════

export type LeaderboardEntry = {
  position: number; // ۱..۵۰
  studentId: string;
  displayName: string;
  avatarUrl: string | null;
  grade: number | null;
  totalPoints: number;
  tier: RankTier;
};

/** مجموع امتیاز هر شاگرد — منبع واحد برای رتبه‌بندی/جدول امتیازات. */
async function totalsQuery(db: D1Database, gradeFilter: number | null) {
  const base =
    `SELECT u.id AS student_id, u.first_name, u.last_name, u.avatar_url, u.current_grade,
            COALESCE(SUM(l.points), 0) AS total
       FROM users u
       LEFT JOIN student_points_ledger l ON l.student_id = u.id
      WHERE u.role = 'student' AND u.status = 'active'`;
  if (gradeFilter != null) {
    return db
      .prepare(`${base} AND u.current_grade = ? GROUP BY u.id ORDER BY total DESC, u.id LIMIT 50`)
      .bind(gradeFilter);
  }
  return db.prepare(`${base} GROUP BY u.id ORDER BY total DESC, u.id LIMIT 50`);
}

export async function getLeaderboard(db: D1Database, scope: 'global' | 'grade', gradeFilter: number | null): Promise<LeaderboardEntry[]> {
  const tiers = await getRankTiers(db);
  const stmt = await totalsQuery(db, scope === 'grade' ? gradeFilter : null);
  const { results } = await stmt.all<{
    student_id: string;
    first_name: string;
    last_name: string;
    avatar_url: string | null;
    current_grade: number | null;
    total: number;
  }>();
  return results.map((r, idx) => ({
    position: idx + 1,
    studentId: r.student_id,
    displayName: `${r.first_name} ${r.last_name}`.trim(),
    avatarUrl: r.avatar_url,
    grade: r.current_grade,
    totalPoints: r.total,
    tier: tierForPoints(tiers, r.total).current,
  }));
}

/** موقعیت سراسری یک شاگرد (۱=بیشترین امتیاز) — حتی اگر بیرون از Top ۵۰ باشد. */
async function computePosition(db: D1Database, studentId: string, totalPoints: number, gradeFilter: number | null): Promise<number> {
  const clause = gradeFilter != null ? "AND u.current_grade = ?" : '';
  const sql = `
    SELECT COUNT(*) AS n FROM (
      SELECT u.id, COALESCE(SUM(l.points), 0) AS total
        FROM users u LEFT JOIN student_points_ledger l ON l.student_id = u.id
       WHERE u.role = 'student' AND u.status = 'active' ${clause}
       GROUP BY u.id
      HAVING total > ?
    )`;
  const row =
    gradeFilter != null
      ? await db.prepare(sql).bind(gradeFilter, totalPoints).first<{ n: number }>()
      : await db.prepare(sql).bind(totalPoints).first<{ n: number }>();
  return (row?.n ?? 0) + 1;
}

export type CompetitionStatus = {
  totalPoints: number;
  tier: RankTier;
  nextTier: RankTier | null;
  pointsToNextTier: number | null;
  progressToNextTierPercent: number;
  globalPosition: number;
  gradePosition: number | null;
  pointsToRankOneGlobal: number | null; // فاصله تا صدرنشین سراسری (۰ اگر خودش صدرنشین است)
  streak: { currentStreak: number; longestStreak: number };
  missionsCompleted: number;
  missionsTotal: number;
};

export async function getCompetitionStatus(db: D1Database, studentId: string): Promise<CompetitionStatus> {
  const totalRow = await db
    .prepare('SELECT COALESCE(SUM(points),0) AS total FROM student_points_ledger WHERE student_id=?')
    .bind(studentId)
    .first<{ total: number }>();
  const totalPoints = totalRow?.total ?? 0;

  const tiers = await getRankTiers(db);
  const { current, next } = tierForPoints(tiers, totalPoints);
  const pointsToNextTier = next ? next.minPoints - totalPoints : null;
  const progressToNextTierPercent = next
    ? Math.round(((totalPoints - current.minPoints) / (next.minPoints - current.minPoints)) * 1000) / 10
    : 100;

  const student = await db.prepare('SELECT current_grade FROM users WHERE id = ?').bind(studentId).first<{ current_grade: number | null }>();
  const grade = student?.current_grade ?? null;

  const globalPosition = await computePosition(db, studentId, totalPoints, null);
  const gradePosition = grade != null ? await computePosition(db, studentId, totalPoints, grade) : null;

  const topRow = await db
    .prepare(
      `SELECT MAX(total) AS top FROM (
         SELECT u.id, COALESCE(SUM(l.points),0) AS total FROM users u
         LEFT JOIN student_points_ledger l ON l.student_id = u.id
         WHERE u.role='student' AND u.status='active' GROUP BY u.id)`,
    )
    .first<{ top: number | null }>();
  const topPoints = topRow?.top ?? totalPoints;
  const pointsToRankOneGlobal = Math.max(0, topPoints - totalPoints);

  const streak = await getStreakStatus(db, studentId);

  const missionCounts = await db
    .prepare(
      `SELECT
         (SELECT COUNT(*) FROM missions WHERE active = 1) AS total,
         (SELECT COUNT(*) FROM student_mission_claims WHERE student_id = ?) AS completed`,
    )
    .bind(studentId)
    .first<{ total: number; completed: number }>();

  return {
    totalPoints,
    tier: current,
    nextTier: next,
    pointsToNextTier,
    progressToNextTierPercent,
    globalPosition,
    gradePosition,
    pointsToRankOneGlobal: globalPosition === 1 ? 0 : pointsToRankOneGlobal,
    streak: { currentStreak: streak.currentStreak, longestStreak: streak.longestStreak },
    missionsCompleted: missionCounts?.completed ?? 0,
    missionsTotal: missionCounts?.total ?? 0,
  };
}

// ═══════════════════════════════ میشن‌ها ════════════════════════════════════

export type MissionWithProgress = {
  id: string;
  category: string;
  titleFa: string;
  descriptionFa: string;
  icon: string;
  targetCount: number;
  pointsReward: number;
  progressCount: number;
  completed: boolean;
  claimed: boolean;
};

export async function getMissionsWithProgress(db: D1Database, studentId: string): Promise<MissionWithProgress[]> {
  const { results } = await db
    .prepare(
      `SELECT m.id, m.category, m.title_fa, m.description_fa, m.icon, m.reason_key, m.target_count, m.points_reward,
              (SELECT COUNT(*) FROM student_points_ledger WHERE student_id = ? AND reason = m.reason_key) AS progress_count,
              (SELECT 1 FROM student_mission_claims WHERE student_id = ? AND mission_id = m.id) AS claimed
         FROM missions m
        WHERE m.active = 1
        ORDER BY m.sort_order`,
    )
    .bind(studentId, studentId)
    .all<{
      id: string;
      category: string;
      title_fa: string;
      description_fa: string;
      icon: string;
      reason_key: string;
      target_count: number;
      points_reward: number;
      progress_count: number;
      claimed: number | null;
    }>();

  return results.map((r) => ({
    id: r.id,
    category: r.category,
    titleFa: r.title_fa,
    descriptionFa: r.description_fa,
    icon: r.icon,
    targetCount: r.target_count,
    pointsReward: r.points_reward,
    progressCount: Math.min(r.progress_count, r.target_count),
    completed: r.progress_count >= r.target_count,
    claimed: r.claimed === 1,
  }));
}

export type ClaimResult =
  | { ok: true; pointsAwarded: number }
  | { ok: false; code: 'NOT_FOUND' | 'NOT_COMPLETED' | 'ALREADY_CLAIMED' };

export async function claimMission(db: D1Database, studentId: string, missionId: string): Promise<ClaimResult> {
  const mission = await db
    .prepare('SELECT id, reason_key, target_count, points_reward FROM missions WHERE id = ? AND active = 1')
    .bind(missionId)
    .first<{ id: string; reason_key: string; target_count: number; points_reward: number }>();
  if (!mission) return { ok: false, code: 'NOT_FOUND' };

  const already = await db
    .prepare('SELECT 1 FROM student_mission_claims WHERE student_id = ? AND mission_id = ?')
    .bind(studentId, missionId)
    .first();
  if (already) return { ok: false, code: 'ALREADY_CLAIMED' };

  const progress = await db
    .prepare('SELECT COUNT(*) AS n FROM student_points_ledger WHERE student_id = ? AND reason = ?')
    .bind(studentId, mission.reason_key)
    .first<{ n: number }>();
  if ((progress?.n ?? 0) < mission.target_count) return { ok: false, code: 'NOT_COMPLETED' };

  try {
    await db
      .prepare('INSERT INTO student_mission_claims (id, student_id, mission_id) VALUES (?, ?, ?)')
      .bind(`mc_${crypto.randomUUID()}`, studentId, missionId)
      .run();
  } catch {
    // ایندکس یکتا (student_id, mission_id) — تلاش هم‌زمان دوباره را رد می‌کند.
    return { ok: false, code: 'ALREADY_CLAIMED' };
  }
  await awardPoints(db, studentId, mission.points_reward, 'mission_reward', missionId);
  return { ok: true, pointsAwarded: mission.points_reward };
}

// ═══════════════════════════ میشن‌های روزانه (Daily Quests) ═════════════════
// جدا از `missions` (دستاوردهای دائمی/یک‌بارهٔ بالا) — این پنل هر روز صفر
// می‌شود، طبق سند طراحی «ماموریت‌های روزانه». `requires_template_id` یک
// قفل زنجیره‌ای ساده می‌سازد: میشن دوم فقط بعد از دریافت پاداش میشن اول
// (در همان روز) در دسترس/قابل‌دریافت می‌شود.

function todayIsoDate(): string {
  return new Date().toISOString().slice(0, 10);
}

export type DailyQuest = {
  id: string; // templateId
  titleFa: string;
  descriptionFa: string;
  icon: string;
  targetCount: number;
  pointsReward: number;
  progressCount: number;
  completed: boolean;
  claimed: boolean;
  /** اگر true باشد، این میشن هنوز به‌خاطر قفل زنجیره‌ای در دسترس نیست —
   * UI باید آن را خاکستری/غیرقابل‌دریافت نشان دهد. */
  locked: boolean;
  requiresQuestId: string | null;
};

/**
 * میشن‌های امروز شاگرد + پیشرفت واقعی هرکدام. اگر امروز هنوز ردیفی برای این
 * شاگرد ساخته نشده (اولین بازدید امروز)، همهٔ الگوهای فعال idempotent
 * (INSERT OR IGNORE) ساخته می‌شوند.
 */
export async function getDailyQuests(db: D1Database, studentId: string): Promise<DailyQuest[]> {
  const today = todayIsoDate();
  const { results: templates } = await db
    .prepare(
      'SELECT id, title_fa, description_fa, icon, reason_key, target_count, points_reward, requires_template_id, sort_order FROM daily_quest_templates WHERE active = 1 ORDER BY sort_order',
    )
    .all<{
      id: string;
      title_fa: string;
      description_fa: string;
      icon: string;
      reason_key: string;
      target_count: number;
      points_reward: number;
      requires_template_id: string | null;
      sort_order: number;
    }>();

  if (templates.length === 0) return [];

  await db.batch(
    templates.map((t) =>
      db
        .prepare('INSERT OR IGNORE INTO student_daily_quests (id, student_id, template_id, quest_date) VALUES (?, ?, ?, ?)')
        .bind(`sdq_${studentId}_${t.id}_${today}`, studentId, t.id, today),
    ),
  );

  const { results: claimedRows } = await db
    .prepare('SELECT template_id FROM student_daily_quests WHERE student_id = ? AND quest_date = ? AND claimed = 1')
    .bind(studentId, today)
    .all<{ template_id: string }>();
  const claimedSet = new Set(claimedRows.map((r) => r.template_id));

  const quests: DailyQuest[] = [];
  for (const t of templates) {
    const progressRow = await db
      .prepare(
        "SELECT COUNT(*) AS n FROM student_points_ledger WHERE student_id = ? AND reason = ? AND date(created_at) = ?",
      )
      .bind(studentId, t.reason_key, today)
      .first<{ n: number }>();
    const progressCount = Math.min(progressRow?.n ?? 0, t.target_count);
    const locked = t.requires_template_id != null && !claimedSet.has(t.requires_template_id);
    quests.push({
      id: t.id,
      titleFa: t.title_fa,
      descriptionFa: t.description_fa,
      icon: t.icon,
      targetCount: t.target_count,
      pointsReward: t.points_reward,
      progressCount,
      completed: progressCount >= t.target_count,
      claimed: claimedSet.has(t.id),
      locked,
      requiresQuestId: t.requires_template_id,
    });
  }
  return quests;
}

export async function claimDailyQuest(db: D1Database, studentId: string, templateId: string): Promise<ClaimResult> {
  const today = todayIsoDate();
  const template = await db
    .prepare('SELECT id, reason_key, target_count, points_reward, requires_template_id FROM daily_quest_templates WHERE id = ? AND active = 1')
    .bind(templateId)
    .first<{ id: string; reason_key: string; target_count: number; points_reward: number; requires_template_id: string | null }>();
  if (!template) return { ok: false, code: 'NOT_FOUND' };

  if (template.requires_template_id) {
    const prereqClaimed = await db
      .prepare('SELECT 1 FROM student_daily_quests WHERE student_id = ? AND template_id = ? AND quest_date = ? AND claimed = 1')
      .bind(studentId, template.requires_template_id, today)
      .first();
    if (!prereqClaimed) return { ok: false, code: 'NOT_COMPLETED' };
  }

  const row = await db
    .prepare('SELECT id, claimed FROM student_daily_quests WHERE student_id = ? AND template_id = ? AND quest_date = ?')
    .bind(studentId, templateId, today)
    .first<{ id: string; claimed: number }>();
  if (!row) return { ok: false, code: 'NOT_FOUND' };
  if (row.claimed === 1) return { ok: false, code: 'ALREADY_CLAIMED' };

  const progressRow = await db
    .prepare("SELECT COUNT(*) AS n FROM student_points_ledger WHERE student_id = ? AND reason = ? AND date(created_at) = ?")
    .bind(studentId, template.reason_key, today)
    .first<{ n: number }>();
  if ((progressRow?.n ?? 0) < template.target_count) return { ok: false, code: 'NOT_COMPLETED' };

  const updateResult = await db
    .prepare("UPDATE student_daily_quests SET claimed = 1, claimed_at = datetime('now') WHERE id = ? AND claimed = 0")
    .bind(row.id)
    .run();
  if ((updateResult.meta?.changes ?? 0) === 0) return { ok: false, code: 'ALREADY_CLAIMED' };

  await awardPoints(db, studentId, template.points_reward, 'daily_quest_reward', templateId);
  return { ok: true, pointsAwarded: template.points_reward };
}

// ═══════════════════════════ کارت آمار پویا (Stats Card) ════════════════════

export type CompetitionStats = {
  /** دقت پاسخ‌دهی در امتحانات/آزمون‌های فصل (۰..۱۰۰) — null اگر هنوز هیچ
   * امتحان/آزمونی نداده. */
  accuracyPercent: number | null;
  examsTaken: number;
  examsPassed: number;
  /** مجموع امتیاز هرکدام از ۷ روز گذشته (امروز آخرین عضو آرایه) — برای
   * نمودار میله‌ای کوچک «پیشرفت هفتگی». */
  weeklyPointsSeries: { date: string; points: number }[];
};

export async function getCompetitionStats(db: D1Database, studentId: string): Promise<CompetitionStats> {
  const examRow = await db
    .prepare(
      `SELECT
         (SELECT COUNT(*) FROM exam_attempts WHERE user_id = ?) +
         (SELECT COUNT(*) FROM chapter_quiz_attempts WHERE user_id = ?) AS taken,
         (SELECT COUNT(*) FROM exam_attempts WHERE user_id = ? AND score_percent >= 80) +
         (SELECT COUNT(*) FROM chapter_quiz_attempts WHERE user_id = ? AND passed = 1) AS passed`,
    )
    .bind(studentId, studentId, studentId, studentId)
    .first<{ taken: number; passed: number }>();
  const taken = examRow?.taken ?? 0;
  const passed = examRow?.passed ?? 0;

  const { results: dailyRows } = await db
    .prepare(
      `SELECT date(created_at) AS d, COALESCE(SUM(points), 0) AS total
         FROM student_points_ledger
        WHERE student_id = ? AND date(created_at) >= date('now', '-6 days')
        GROUP BY date(created_at)`,
    )
    .bind(studentId)
    .all<{ d: string; total: number }>();
  const byDate = new Map(dailyRows.map((r) => [r.d, r.total] as const));

  const series: { date: string; points: number }[] = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date();
    d.setUTCDate(d.getUTCDate() - i);
    const iso = d.toISOString().slice(0, 10);
    series.push({ date: iso, points: byDate.get(iso) ?? 0 });
  }

  return {
    accuracyPercent: taken > 0 ? Math.round((passed / taken) * 1000) / 10 : null,
    examsTaken: taken,
    examsPassed: passed,
    weeklyPointsSeries: series,
  };
}
