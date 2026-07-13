/**
 * routes/seminars.ts — سمینارهای زنده (بخش ۱۲/۱۹.۸ سند).
 *
 * Endpointها (زیر `/api/v1`):
 *   GET  /seminars?audience=students|parents&instructor=<id>
 *   GET  /seminars/:id
 *   POST /seminars                      (استاد/مدیر) ساخت
 *   POST /seminars/:id/register         (کاربر) ثبت‌نام یک‌بار
 *   PATCH /seminars/:id/status          (استاد/مدیر) تغییر وضعیت
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  // ── Cloudflare Stream (پخش زندهٔ سمینار). همه اختیاری‌اند؛ اگر تنظیم نشوند،
  //    مسیرهای go-live با ۵۰۳ پاسخ می‌دهند و اپ به لینک دستی (meetingLink) برمی‌گردد.
  CF_ACCOUNT_ID?: string; // شناسهٔ حساب Cloudflare
  CF_STREAM_TOKEN?: string; // توکن API با دسترسی Stream:Edit (از wrangler secret)
  CF_STREAM_CUSTOMER?: string; // زیردامنهٔ مشتری استریم (customer-XXXX)
};

const seminars = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en } };
}

async function auth(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

async function toSeminarJson(c: any, row: any): Promise<any> {
  const { results } = await c.env.DB.prepare(
    'SELECT user_id FROM seminar_registrations WHERE seminar_id = ?',
  )
    .bind(row.id)
    .all<{ user_id: string }>();
  // نشانی DASH را از روی stream_uid و زیردامنهٔ مشتری می‌سازیم (اگر پیکربندی شده باشد).
  const customer = c.env.CF_STREAM_CUSTOMER as string | undefined;
  const dash =
    row.stream_uid && customer ? streamDashUrl(customer, row.stream_uid) : '';
  return {
    id: row.id,
    title: row.title,
    description: row.description,
    instructorId: row.instructor_id,
    instructorName: row.instructor_name,
    scheduledStart: row.scheduled_start,
    durationMinutes: row.duration_minutes,
    status: row.status,
    capacity: row.capacity,
    audience: row.audience,
    meetingLink: row.meeting_link ?? '',
    streamUid: row.stream_uid ?? '',
    streamPlaybackUrl: row.stream_playback_url ?? '',
    streamDashUrl: dash,
    registeredUserIds: results.map((r) => r.user_id),
  };
}

// ─────────────────────── Cloudflare Stream helpers ─────────────────────────

/// نشانی پخش HLS برای یک ورودیِ زندهٔ استریم را می‌سازد.
function streamHlsUrl(customer: string, videoUid: string): string {
  return `https://customer-${customer}.cloudflarestream.com/${videoUid}/manifest/video.m3u8`;
}

/// نشانی پخش DASH (MPEG-DASH) — برای پخش‌کننده‌هایی که DASH را ترجیح می‌دهند.
function streamDashUrl(customer: string, videoUid: string): string {
  return `https://customer-${customer}.cloudflarestream.com/${videoUid}/manifest/video.mpd`;
}

/// آیا Cloudflare Stream روی این محیط پیکربندی شده است؟
function streamConfigured(c: any): boolean {
  return Boolean(c.env.CF_ACCOUNT_ID && c.env.CF_STREAM_TOKEN && c.env.CF_STREAM_CUSTOMER);
}

// ─────────────────────────────── فهرست ─────────────────────────────────────

seminars.get('/seminars', async (c) => {
  const audience = c.req.query('audience');
  const instructor = c.req.query('instructor');
  const clauses: string[] = ['1=1'];
  const binds: any[] = [];
  if (instructor) {
    clauses.push('instructor_id = ?');
    binds.push(instructor);
  } else if (audience) {
    // نمای شاگرد/والد: فقط منتشرشده/زنده و پایان‌نیافته (بخش ۱۲.۲).
    clauses.push('audience = ?');
    binds.push(audience);
    clauses.push("status IN ('published','registrationClosed','live')");
  }
  const { results } = await c.env.DB.prepare(
    `SELECT * FROM seminars WHERE ${clauses.join(' AND ')} ORDER BY scheduled_start`,
  )
    .bind(...binds)
    .all<any>();
  const list = [];
  for (const row of results) list.push(await toSeminarJson(c, row));
  return c.json({ seminars: list });
});

// ── کلاس‌های زندهٔ همین‌حالا (استریم فعال) ─────────────────────────────────
// خروجی: سمینارهایی که استاد پخش زنده را شروع کرده (status='live' و نشانی پخش
// دارند)، همراه با HLS و DASH؛ برای نمای «زندهٔ اکنون» شاگرد/والد.
// باید پیش از مسیر پارامتری `/seminars/:id` ثبت شود تا «live» به‌عنوان id گرفته نشود.
seminars.get('/seminars/live', async (c) => {
  const audience = c.req.query('audience');
  const clauses: string[] = ["status = 'live'", "stream_playback_url != ''"];
  const binds: any[] = [];
  if (audience) {
    clauses.push('audience = ?');
    binds.push(audience);
  }
  const { results } = await c.env.DB.prepare(
    `SELECT * FROM seminars WHERE ${clauses.join(' AND ')} ORDER BY scheduled_start`,
  )
    .bind(...binds)
    .all<any>();
  const list = [];
  for (const row of results) list.push(await toSeminarJson(c, row));
  return c.json({ seminars: list });
});

seminars.get('/seminars/:id', async (c) => {
  const row = await c.env.DB.prepare('SELECT * FROM seminars WHERE id = ?')
    .bind(c.req.param('id'))
    .first<any>();
  if (!row) return c.json(fail('NOT_FOUND', 'سمینار یافت نشد', 'Seminar not found'), 404);
  return c.json({ seminar: await toSeminarJson(c, row) });
});

// ── فهرست ثبت‌نامی‌های یک سمینار (فقط استاد/مدیر) — همراه با نام کاربر ────────
seminars.get('/seminars/:id/registrations', async (c) => {
  const me = await auth(c);
  if (!me || (me.role !== 'seminar_instructor' && me.role !== 'super_admin')) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  }
  const { results } = await c.env.DB.prepare(
    `SELECT r.user_id AS userId,
            TRIM(COALESCE(u.first_name,'') || ' ' || COALESCE(u.last_name,'')) AS name,
            u.role AS role,
            r.status AS status,
            r.registered_at AS registeredAt
       FROM seminar_registrations r
       LEFT JOIN users u ON u.id = r.user_id
      WHERE r.seminar_id = ?
      ORDER BY r.registered_at`,
  )
    .bind(c.req.param('id'))
    .all<any>();
  return c.json({
    registrations: results.map((r) => ({
      userId: r.userId,
      name: (r.name as string)?.trim() ? r.name : '—',
      role: r.role ?? '',
      status: r.status ?? 'registered',
      registeredAt: r.registeredAt ?? '',
    })),
  });
});

// ─────────────────────────────── ساخت ──────────────────────────────────────

seminars.post('/seminars', async (c) => {
  const me = await auth(c);
  if (!me || (me.role !== 'seminar_instructor' && me.role !== 'super_admin')) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  }
  const b = await c.req.json<any>().catch(() => null);
  if (!b?.title || !b?.scheduledStart) {
    return c.json(fail('BAD_REQUEST', 'عنوان و زمان الزامی است', 'Missing fields'), 400);
  }
  // نام استاد: اگر در بدنه آمده (مثلاً مدیر به‌نمایندگی می‌سازد) همان؛ وگرنه از رکورد کاربر.
  let instructorName = String(b.instructorName ?? '').trim();
  if (!instructorName) {
    const u = await c.env.DB.prepare('SELECT first_name, last_name FROM users WHERE id = ?')
      .bind(me.sub)
      .first<{ first_name: string; last_name: string }>();
    instructorName = u ? `${u.first_name} ${u.last_name}`.trim() : '';
  }
  const id = uid();
  await c.env.DB.prepare(
    `INSERT INTO seminars (id, title, description, instructor_id, instructor_name, scheduled_start, duration_minutes, status, capacity, audience, meeting_link)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      id,
      String(b.title),
      String(b.description ?? ''),
      me.sub,
      instructorName,
      String(b.scheduledStart),
      Number(b.durationMinutes ?? 45),
      String(b.status ?? 'published'),
      b.capacity != null ? Number(b.capacity) : null,
      b.audience === 'parents' ? 'parents' : 'students',
      String(b.meetingLink ?? ''),
    )
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM seminars WHERE id = ?').bind(id).first<any>();
  return c.json({ seminar: await toSeminarJson(c, row) }, 201);
});

// ─────────────────────────────── ثبت‌نام ────────────────────────────────────

seminars.post('/seminars/:id/register', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const seminarId = c.req.param('id');
  const s = await c.env.DB.prepare('SELECT * FROM seminars WHERE id = ?')
    .bind(seminarId)
    .first<any>();
  if (!s) return c.json(fail('NOT_FOUND', 'سمینار یافت نشد', 'Seminar not found'), 404);

  const already = await c.env.DB.prepare(
    'SELECT 1 FROM seminar_registrations WHERE seminar_id = ? AND user_id = ?',
  )
    .bind(seminarId, me.sub)
    .first();
  if (already) return c.json(fail('ALREADY_REGISTERED', 'شما قبلاً ثبت‌نام کرده‌اید', 'Already registered'), 409);

  if (s.status === 'registrationClosed' || s.status === 'ended' || s.status === 'archived') {
    return c.json(fail('REGISTRATION_CLOSED', 'ثبت‌نام این سمینار بسته است', 'Registration closed'), 400);
  }
  if (s.capacity != null) {
    const { results } = await c.env.DB.prepare(
      'SELECT COUNT(*) AS n FROM seminar_registrations WHERE seminar_id = ?',
    )
      .bind(seminarId)
      .all<{ n: number }>();
    if ((results[0]?.n ?? 0) >= s.capacity) {
      return c.json(fail('FULL', 'ظرفیت تکمیل است', 'Seminar full'), 400);
    }
  }
  await c.env.DB.prepare(
    'INSERT INTO seminar_registrations (seminar_id, user_id) VALUES (?, ?)',
  )
    .bind(seminarId, me.sub)
    .run();
  return c.json({ success: true });
});

// ─────────────────────────── ویرایش کامل ────────────────────────────────────

seminars.put('/seminars/:id', async (c) => {
  const me = await auth(c);
  if (!me || (me.role !== 'seminar_instructor' && me.role !== 'super_admin')) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  }
  const id = c.req.param('id');
  const existing = await c.env.DB.prepare('SELECT id FROM seminars WHERE id = ?').bind(id).first();
  if (!existing) return c.json(fail('NOT_FOUND', 'سمینار یافت نشد', 'Seminar not found'), 404);
  const b = await c.req.json<any>().catch(() => null);
  if (!b) return c.json(fail('BAD_REQUEST', 'بدنهٔ نامعتبر', 'Invalid body'), 400);
  await c.env.DB.prepare(
    `UPDATE seminars SET
       title = COALESCE(?, title),
       description = COALESCE(?, description),
       instructor_name = COALESCE(?, instructor_name),
       scheduled_start = COALESCE(?, scheduled_start),
       duration_minutes = COALESCE(?, duration_minutes),
       status = COALESCE(?, status),
       capacity = ?,
       audience = COALESCE(?, audience),
       meeting_link = COALESCE(?, meeting_link)
     WHERE id = ?`,
  )
    .bind(
      b.title ?? null,
      b.description ?? null,
      b.instructorName ?? null,
      b.scheduledStart ?? null,
      b.durationMinutes != null ? Number(b.durationMinutes) : null,
      b.status ?? null,
      b.capacity != null ? Number(b.capacity) : null,
      b.audience ?? null,
      b.meetingLink ?? null,
      id,
    )
    .run();
  return c.json({ success: true });
});

seminars.delete('/seminars/:id', async (c) => {
  const me = await auth(c);
  if (!me || (me.role !== 'seminar_instructor' && me.role !== 'super_admin')) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  }
  const id = c.req.param('id');
  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM seminar_registrations WHERE seminar_id = ?').bind(id),
    c.env.DB.prepare('DELETE FROM seminars WHERE id = ?').bind(id),
  ]);
  return c.json({ success: true });
});

// ──────────────────────────── تغییر وضعیت ───────────────────────────────────

seminars.patch('/seminars/:id/status', async (c) => {
  const me = await auth(c);
  if (!me || (me.role !== 'seminar_instructor' && me.role !== 'super_admin')) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  }
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  const valid = ['draft', 'published', 'registrationClosed', 'live', 'ended', 'archived'];
  if (!b?.status || !valid.includes(b.status)) {
    return c.json(fail('BAD_REQUEST', 'وضعیت نامعتبر', 'Invalid status'), 400);
  }
  await c.env.DB.prepare('UPDATE seminars SET status = ? WHERE id = ?')
    .bind(b.status, c.req.param('id'))
    .run();
  return c.json({ success: true });
});

// ───────────────────────── شروع پخش زنده (go-live) ─────────────────────────
// استاد/مدیر یک ورودیِ زندهٔ Cloudflare Stream می‌سازد (یا موجود را بازمی‌یابد)،
// نشانی پخش HLS برای شاگردان ذخیره می‌شود، وضعیت سمینار به «live» می‌رود، و
// اطلاعات پخش (RTMPS + کلید) برای استاد بازگردانده می‌شود تا با OBS/موبایل پخش کند.
seminars.post('/seminars/:id/go-live', async (c) => {
  const me = await auth(c);
  if (!me || (me.role !== 'seminar_instructor' && me.role !== 'super_admin')) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  }
  const id = c.req.param('id');
  const sem = await c.env.DB.prepare('SELECT * FROM seminars WHERE id = ?').bind(id).first<any>();
  if (!sem) {
    return c.json(fail('NOT_FOUND', 'سمینار یافت نشد', 'Seminar not found'), 404);
  }
  if (!streamConfigured(c)) {
    return c.json(
      fail(
        'STREAM_NOT_CONFIGURED',
        'پخش زنده هنوز روی سرور پیکربندی نشده است. از لینک جلسهٔ دستی استفاده کنید.',
        'Cloudflare Stream is not configured on the server.',
      ),
      503,
    );
  }

  const acct = c.env.CF_ACCOUNT_ID as string;
  const token = c.env.CF_STREAM_TOKEN as string;
  const customer = c.env.CF_STREAM_CUSTOMER as string;
  const base = `https://api.cloudflare.com/client/v4/accounts/${acct}/stream/live_inputs`;
  const headers = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

  try {
    let liveInput: any;
    if (sem.stream_uid) {
      // بازیابی ورودیِ موجود (کلید پخش دوباره واکشی می‌شود).
      const res = await fetch(`${base}/${sem.stream_uid}`, { headers });
      const data = (await res.json()) as any;
      if (res.ok && data?.result) liveInput = data.result;
    }
    if (!liveInput) {
      const res = await fetch(base, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          meta: { name: `AGDS • ${sem.title ?? id}` },
          recording: { mode: 'automatic', timeoutSeconds: 10 },
        }),
      });
      const data = (await res.json()) as any;
      if (!res.ok || !data?.result) {
        return c.json(
          fail('STREAM_ERROR', 'ساخت پخش زنده ناموفق بود', 'Failed to create live input'),
          502,
        );
      }
      liveInput = data.result;
    }

    const videoUid = liveInput.uid as string;
    const playback = streamHlsUrl(customer, videoUid);
    await c.env.DB.prepare(
      "UPDATE seminars SET stream_uid = ?, stream_playback_url = ?, status = 'live' WHERE id = ?",
    )
      .bind(videoUid, playback, id)
      .run();

    return c.json({
      success: true,
      streamUid: videoUid,
      playbackUrl: playback,
      // اطلاعات پخش برای استاد (در اپ نمایش داده می‌شود تا با OBS/Larix پخش کند):
      rtmpsUrl: liveInput.rtmps?.url ?? '',
      rtmpsKey: liveInput.rtmps?.streamKey ?? '',
      srtUrl: liveInput.srt?.url ?? '',
      whipUrl: liveInput.webRTC?.url ?? '',
    });
  } catch (e) {
    return c.json(
      fail('STREAM_ERROR', 'خطا در ارتباط با Cloudflare Stream', 'Cloudflare Stream request failed'),
      502,
    );
  }
});

// ───────────────────────── پایان پخش زنده (end-live) ───────────────────────
seminars.post('/seminars/:id/end-live', async (c) => {
  const me = await auth(c);
  if (!me || (me.role !== 'seminar_instructor' && me.role !== 'super_admin')) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  }
  const id = c.req.param('id');
  await c.env.DB.prepare("UPDATE seminars SET status = 'ended' WHERE id = ?").bind(id).run();
  return c.json({ success: true });
});

export default seminars;
