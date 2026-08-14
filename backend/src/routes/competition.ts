/**
 * routes/competition.ts — «رقابت مکتب» (نسخهٔ ۲): جدول رتبه‌بندی سراسری،
 * ۵۰ مقام، وضعیت من در رقابت، میشن‌ها + دریافت پاداش. زیر `/api/v1` mount
 * می‌شود (نگاه کن به index.ts). منطق واقعی در lib/competition.ts است؛ این
 * فایل فقط Endpointها را تعریف/احراز هویت می‌کند — دقیقاً هم‌الگو با بقیهٔ
 * روترهای پروژه (مثل chapterQuizzes.ts).
 *
 * Endpointها:
 *   GET  /competition/rank-tiers                 فهرست کامل ۵۰ مقام (ثابت/کش‌پذیر)
 *   GET  /competition/leaderboard?scope=&grade=  جدول امتیازات Top ۵۰
 *   GET  /competition/me                          وضعیت رقابتی شاگرد وارد‌شده
 *   GET  /competition/missions                    فهرست میشن‌ها + پیشرفت من
 *   POST /competition/missions/:id/claim          دریافت پاداش یک میشن تکمیل‌شده
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import {
  getRankTiers,
  getLeaderboard,
  getCompetitionStatus,
  getMissionsWithProgress,
  claimMission,
  getDailyQuests,
  claimDailyQuest,
  getCompetitionStats,
} from '../lib/competition';

type Bindings = { DB: D1Database; JWT_SECRET: string };
const competition = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function auth(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

competition.get('/competition/rank-tiers', async (c) => {
  if (!(await auth(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const tiers = await getRankTiers(c.env.DB);
  return c.json({ tiers });
});

competition.get('/competition/leaderboard', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const scope = c.req.query('scope') === 'grade' ? 'grade' : 'global';
  let gradeFilter: number | null = null;
  if (scope === 'grade') {
    const q = c.req.query('grade');
    if (q) gradeFilter = Number(q);
    else {
      const student = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?').bind(me.sub).first<{ current_grade: number | null }>();
      gradeFilter = student?.current_grade ?? null;
    }
  }
  const entries = await getLeaderboard(c.env.DB, scope, gradeFilter);
  return c.json({ scope, grade: gradeFilter, entries });
});

competition.get('/competition/me', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const status = await getCompetitionStatus(c.env.DB, me.sub);
  return c.json(status);
});

competition.get('/competition/missions', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const missions = await getMissionsWithProgress(c.env.DB, me.sub);
  return c.json({ missions });
});

competition.post('/competition/missions/:id/claim', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const missionId = c.req.param('id');
  const result = await claimMission(c.env.DB, me.sub, missionId);
  if (!result.ok) {
    const messages: Record<string, [string, string]> = {
      NOT_FOUND: ['میشن یافت نشد', 'Mission not found'],
      NOT_COMPLETED: ['این میشن هنوز تکمیل نشده', 'This mission is not completed yet'],
      ALREADY_CLAIMED: ['پاداش این میشن قبلاً دریافت شده', 'This mission reward has already been claimed'],
    };
    const [fa, en] = messages[result.code];
    return c.json(fail(result.code, fa, en), result.code === 'NOT_FOUND' ? 404 : 409);
  }
  return c.json({ success: true, pointsAwarded: result.pointsAwarded });
});

// ─────────────────────────── میشن‌های روزانه ─────────────────────────────────

competition.get('/competition/daily-quests', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const quests = await getDailyQuests(c.env.DB, me.sub);
  return c.json({ quests });
});

competition.post('/competition/daily-quests/:id/claim', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const templateId = c.req.param('id');
  const result = await claimDailyQuest(c.env.DB, me.sub, templateId);
  if (!result.ok) {
    const messages: Record<string, [string, string]> = {
      NOT_FOUND: ['میشن روزانه یافت نشد', 'Daily quest not found'],
      NOT_COMPLETED: ['این میشن هنوز تکمیل یا قفل است', 'This quest is not completed or is still locked'],
      ALREADY_CLAIMED: ['پاداش امروز این میشن قبلاً دریافت شده', 'Today\'s reward for this quest has already been claimed'],
    };
    const [fa, en] = messages[result.code];
    return c.json(fail(result.code, fa, en), result.code === 'NOT_FOUND' ? 404 : 409);
  }
  return c.json({ success: true, pointsAwarded: result.pointsAwarded });
});

// ─────────────────────────────── کارت آمار ───────────────────────────────────

competition.get('/competition/stats', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const stats = await getCompetitionStats(c.env.DB, me.sub);
  return c.json(stats);
});

export default competition;
