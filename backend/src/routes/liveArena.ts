/**
 * routes/liveArena.ts — «آرنای زنده» (نبرد هفتگی زندهٔ رتبه‌بندی): وضعیت
 * رویداد جاری/بعدی، اتصال WebSocket به اتاق زندهٔ آن (Durable Object در
 * lib/liveArenaRoom.ts)، نتایج نهایی، و زمان‌بندی رویداد بعدی (فقط مدیر).
 * زیر `/api/v1` mount می‌شود — دقیقاً هم‌الگو با competition.ts.
 *
 * نکتهٔ احراز هویت WebSocket: مرورگر (Flutter Web) اجازهٔ ست‌کردن هدر دلخواه
 * روی درخواست WebSocket را نمی‌دهد؛ به همین خاطر توکن اینجا از querystring
 * خوانده می‌شود (`?token=`)، نه هدر `Authorization` — الگوی استاندارد برای
 * احراز هویت WebSocket در مرورگر.
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { getCurrentOrLatestArenaEvent, getArenaEventById, checkEligibility, getStandings } from '../lib/liveArena';

type Bindings = { DB: D1Database; JWT_SECRET: string; LIVE_ARENA_ROOM: DurableObjectNamespace };
const liveArena = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function auth(c: any): Promise<{ sub: string; role: string; firstName?: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

liveArena.get('/live-arena/current', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const event = await getCurrentOrLatestArenaEvent(c.env.DB);
  if (!event) return c.json({ event: null });
  const { eligible, myRankNo } = await checkEligibility(c.env.DB, me.sub, event);
  return c.json({
    event: {
      id: event.id,
      titleFa: event.title_fa,
      startsAt: event.starts_at,
      endsAt: event.ends_at,
      status: event.status,
      minRankNo: event.min_rank_no,
      questionCount: event.question_count,
      timeLimitSeconds: event.time_limit_seconds,
      championStudentId: event.champion_student_id,
      championPoints: event.champion_points,
    },
    eligible,
    myRankNo,
  });
});

liveArena.get('/live-arena/:eventId/results', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const eventId = c.req.param('eventId');
  const standings = await getStandings(c.env.DB, eventId, 50);
  return c.json({ standings });
});

// ─────────────────────── اتصال زنده (WebSocket → Durable Object) ─────────────
liveArena.get('/live-arena/:eventId/socket', async (c) => {
  const token = c.req.query('token');
  const payload = token ? await verifyBearer(`Bearer ${token}`, c.env.JWT_SECRET) : null;
  if (!payload?.['sub']) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const studentId = payload['sub'] as string;

  const eventId = c.req.param('eventId');
  const event = await getArenaEventById(c.env.DB, eventId);
  if (!event) return c.json(fail('NOT_FOUND', 'رویداد یافت نشد', 'Event not found'), 404);

  const { eligible } = await checkEligibility(c.env.DB, studentId, event);
  if (!eligible) {
    return c.json(
      fail('NOT_ELIGIBLE', 'مقام شما هنوز برای این آرنا کافی نیست', 'Your rank is not high enough for this arena yet'),
      403,
    );
  }

  const student = await c.env.DB.prepare('SELECT first_name, last_name FROM users WHERE id = ?').bind(studentId).first<{
    first_name: string;
    last_name: string;
  }>();
  const displayName = student ? `${student.first_name} ${student.last_name}`.trim() : '';

  const id = c.env.LIVE_ARENA_ROOM.idFromName(eventId);
  const stub = c.env.LIVE_ARENA_ROOM.get(id);
  const forwardUrl = new URL(c.req.url);
  forwardUrl.pathname = '/socket';
  forwardUrl.searchParams.set('eventId', eventId);
  forwardUrl.searchParams.set('studentId', studentId);
  forwardUrl.searchParams.set('displayName', displayName);
  return stub.fetch(new Request(forwardUrl.toString(), c.req.raw));
});

// ───────────────────────── زمان‌بندی رویداد بعدی (فقط مدیر) ──────────────────
liveArena.post('/admin/live-arena/schedule', async (c) => {
  const me = await auth(c);
  if (!me || (me.role !== 'admin' && me.role !== 'super_admin')) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  }
  const body = await c.req.json<{
    titleFa?: string;
    startsAt: string;
    durationMinutes?: number;
    minRankNo?: number;
    questionCount?: number;
    timeLimitSeconds?: number;
  }>();
  if (!body?.startsAt) return c.json(fail('BAD_REQUEST', 'زمان شروع لازم است', 'startsAt is required'), 400);

  const questionCount = body.questionCount ?? 10;
  const timeLimitSeconds = body.timeLimitSeconds ?? 15;
  const minRankNo = body.minRankNo ?? 21;
  const durationMinutes = body.durationMinutes ?? Math.ceil((questionCount * (timeLimitSeconds + 4)) / 60) + 5;
  const eventId = `arena_${crypto.randomUUID()}`;

  await c.env.DB.prepare(
    `INSERT INTO arena_events (id, title_fa, starts_at, ends_at, status, min_rank_no, question_count, time_limit_seconds)
     VALUES (?, ?, ?, datetime(?, '+' || ? || ' minutes'), 'scheduled', ?, ?, ?)`,
  )
    .bind(eventId, body.titleFa ?? 'میدان ستارگان هفتگی', body.startsAt, body.startsAt, durationMinutes, minRankNo, questionCount, timeLimitSeconds)
    .run();

  await c.env.DB.prepare(
    `INSERT INTO arena_event_questions (event_id, seq, question_id)
     SELECT ?, (ROW_NUMBER() OVER (ORDER BY RANDOM())) - 1, id
       FROM arena_question_bank WHERE active = 1 LIMIT ?`,
  )
    .bind(eventId, questionCount)
    .run();

  return c.json({ success: true, eventId });
});

export default liveArena;
export type { Bindings as LiveArenaBindings };
