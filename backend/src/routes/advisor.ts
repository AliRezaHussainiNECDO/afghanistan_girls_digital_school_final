/**
 * routes/advisor.ts — «مشاور هوشمند» (رفع اشکال حیاتی امنیتی).
 *
 * قبلاً گفتگوی مشاور فقط در حافظهٔ محلی گوشیِ شاگرد (AdvisorStore) بود و
 * هرگز به سرور نمی‌رسید. اکنون هر پیام (هم شاگرد و هم پاسخ مشاور، که روی
 * کلاینت تولید می‌شود) روی سرور ثبت می‌گردد تا مدیر واقعی مکتب بتواند در
 * جزئیات شاگرد آن را ببیند، و پیام‌های «پرچم‌شده» (نشانهٔ نگرانی/آسیب) فوراً
 * برای همهٔ مدیران Super Admin به‌صورت اعلان واقعی (جدول notifications)
 * ارسال شود.
 *
 * Endpointها (زیر `/api/v1`):
 *   POST /advisor/messages                        ثبت یک پیام (شاگرد جاری)
 *   GET  /advisor/messages                         تاریخچهٔ شاگرد جاری
 *   GET  /admin/advisor/threads                    فهرست گفتگوها (فقط مدیر)
 *   GET  /admin/advisor/students/:studentId/messages   تاریخچهٔ یک شاگرد (فقط مدیر)
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

const advisor = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en } };
}

async function me(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

async function isAdmin(c: any): Promise<boolean> {
  const u = await me(c);
  return u?.role === 'super_admin';
}

function toJson(r: any) {
  return {
    id: r.id,
    studentId: r.student_id,
    studentName: r.student_name,
    role: r.role,
    text: r.text,
    topic: r.topic,
    flagged: Number(r.flagged) === 1,
    createdAt: r.created_at,
  };
}

// ─────────────────────────── شاگرد ───────────────────────────

advisor.post('/advisor/messages', async (c) => {
  const u = await me(c);
  if (!u) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const body = await c.req.json<{
    role: 'student' | 'advisor';
    text: string;
    topic?: string;
    flagged?: boolean;
    studentName?: string;
  }>().catch(() => null);
  if (!body || !body.text || (body.role !== 'student' && body.role !== 'advisor')) {
    return c.json(fail('BAD_REQUEST', 'داده نامعتبر', 'Bad request'), 400);
  }

  let studentName = body.studentName ?? '';
  if (!studentName) {
    const row = await c.env.DB.prepare('SELECT first_name, last_name FROM users WHERE id = ?')
      .bind(u.sub)
      .first<{ first_name: string; last_name: string }>();
    studentName = row ? `${row.first_name} ${row.last_name}`.trim() : '';
  }

  const id = uid();
  const flagged = body.flagged === true;
  await c.env.DB.prepare(
    'INSERT INTO advisor_messages (id, student_id, student_name, role, text, topic, flagged) VALUES (?, ?, ?, ?, ?, ?, ?)',
  )
    .bind(id, u.sub, studentName, body.role, body.text, body.topic ?? 'عمومی', flagged ? 1 : 0)
    .run();

  // پیام حساس → اعلان واقعی و فوری برای همهٔ مدیران.
  if (flagged) {
    const { results: admins } = await c.env.DB.prepare("SELECT id FROM users WHERE role = 'super_admin'").all<{
      id: string;
    }>();
    for (const a of admins) {
      await c.env.DB.prepare(
        "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind) VALUES (?, ?, ?, ?, 'high', 'safety')",
      )
        .bind(
          uid(),
          a.id,
          'گفتگوی مشاور نیاز به توجه دارد 💙',
          `${studentName || 'یک شاگرد'} پیامی حساس ارسال کرد — لطفاً در جزئیات شاگرد بازبینی شود.`,
        )
        .run();
    }
  }

  return c.json({ id, flagged });
});

advisor.get('/advisor/messages', async (c) => {
  const u = await me(c);
  if (!u) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM advisor_messages WHERE student_id = ? ORDER BY created_at ASC',
  )
    .bind(u.sub)
    .all<any>();
  return c.json(results.map(toJson));
});

// ─────────────────────────── مدیر ───────────────────────────

advisor.get('/admin/advisor/threads', async (c) => {
  if (!(await isAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const { results } = await c.env.DB.prepare(
    `SELECT student_id,
            MAX(student_name) AS student_name,
            COUNT(*) AS message_count,
            MAX(created_at) AS last_at,
            MAX(flagged) AS has_flag
     FROM advisor_messages
     GROUP BY student_id
     ORDER BY last_at DESC`,
  ).all<any>();
  return c.json(
    results.map((r) => ({
      studentId: r.student_id,
      studentName: r.student_name,
      messageCount: r.message_count,
      lastAt: r.last_at,
      hasFlag: Number(r.has_flag) === 1,
    })),
  );
});

advisor.get('/admin/advisor/students/:studentId/messages', async (c) => {
  if (!(await isAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM advisor_messages WHERE student_id = ? ORDER BY created_at ASC',
  )
    .bind(c.req.param('studentId'))
    .all<any>();
  return c.json(results.map(toJson));
});

export default advisor;
