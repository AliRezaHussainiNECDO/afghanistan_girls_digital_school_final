/**
 * routes/engagement.ts — حاضری و اعلان‌ها (بخش ۹ و ۱۳ سند).
 *
 * Endpointها (زیر `/api/v1`):
 *   GET   /attendance/:studentId/summary   حاضری از فعالیت واقعی (بخش ۹.۱)
 *   GET   /notifications                   اعلان‌های کاربر فعلی
 *   PATCH /notifications/:id/read          علامت‌گذاری خوانده‌شده
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

const engage = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function auth(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

// ────────────────────────────── حاضری ───────────────────────────────────────
// یک روز «حاضر» است اگر حداقل یک بازدید درس یا یک تلاش امتحان در آن روز باشد
// (بخش ۹.۱). محاسبه روی ۱۴ روز اخیر.

engage.get('/attendance/:studentId/summary', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const target = me.role === 'super_admin' ? c.req.param('studentId') : me.sub;

  // تاریخ‌های دارای فعالیت در ۱۴ روز اخیر (بازدید درس یا تلاش امتحان).
  const { results } = await c.env.DB.prepare(
    `SELECT DISTINCT d FROM (
        SELECT date(viewed_at) AS d FROM student_lesson_views
          WHERE user_id = ? AND viewed_at >= date('now','-13 days')
        UNION
        SELECT date(submitted_at) AS d FROM exam_attempts
          WHERE user_id = ? AND submitted_at >= date('now','-13 days')
     )`,
  )
    .bind(target, target)
    .all<{ d: string }>();
  const activeDays = new Set(results.map((r) => r.d));

  const recentDays: { date: string; status: string }[] = [];
  let present = 0;
  const now = new Date();
  for (let i = 13; i >= 0; i--) {
    const day = new Date(now.getTime() - i * 86400000);
    const iso = day.toISOString().slice(0, 10); // YYYY-MM-DD
    const isPresent = activeDays.has(iso);
    if (isPresent) present++;
    recentDays.push({ date: day.toISOString(), status: isPresent ? 'present' : 'absent' });
  }
  const ratePercent = Math.round((present / 14) * 1000) / 10;

  return c.json({ ratePercent, recentDays });
});

// ─────────────────────────────── اعلان‌ها ───────────────────────────────────

engage.get('/notifications', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 100',
  )
    .bind(me.sub)
    .all<any>();
  const list = results.map((n) => ({
    id: n.id,
    titleFa: n.title_fa,
    bodyFa: n.body_fa,
    priority: n.priority,
    kind: n.kind,
    createdAt: n.created_at,
    read: n.read_at != null,
  }));
  return c.json({ notifications: list });
});

engage.patch('/notifications/:id/read', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  await c.env.DB.prepare(
    "UPDATE notifications SET read_at = datetime('now') WHERE id = ? AND user_id = ?",
  )
    .bind(c.req.param('id'), me.sub)
    .run();
  return c.json({ success: true });
});

export default engage;
