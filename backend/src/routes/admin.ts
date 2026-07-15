/**
 * routes/admin.ts — مدیریت کاربران و کدهای دعوت (بخش ۱۵.۲ و ۳ب.۳ سند).
 * فقط برای Super Admin (بررسی نقش از JWT).
 *
 * Endpointها (زیر `/api/v1/admin`):
 *   GET    /users?role=&q=
 *   PATCH  /users/:id/toggle-suspend
 *   PATCH  /users/:id                       body {status}
 *   GET    /invite-codes?type=&status=
 *   POST   /invite-codes/bulk-generate      body {type,count,batchLabel}
 *   PATCH  /invite-codes/:id/revoke
 *   GET    /system-health                   پایش زندهٔ اتصال سرور/دیتابیس/ذخیره‌سازی
 *   ── مدیریت تفصیلی شاگرد (بخش ۱۵.۲) ──
 *   GET    /students?q=&grade=&province=&status=&at_risk=&page=   لیست صفحه‌بندی‌شده
 *   GET    /students/:id                    جزئیات کامل تحصیلی (پیشرفت مطابق داشبورد شاگرد/والد)
 *   GET    /students/:id/ai-report          گزارش معلم هوشمند (محاسبه‌شده از داده واقعی)
 *   PATCH  /students/:id/status             body {status, reason}
 *   POST   /students/:id/password-reset-link ارسال کد بازیابی به ایمیل شاگرد
 *   ── نصاب هوشمند (بخش شناسایی فصل از کتاب) ──
 *   POST   /curriculum/subjects/:subjectId/publish-chapters   انتشار فصل‌های شناسایی‌شده از یک کتاب
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import {
  sendEmail,
  resetEmailHtml,
  sha256B64Url,
  randomSixDigitCode,
} from '../lib/email';
import { getSubjectProgressList, averagePercent, getPointsSummary } from '../lib/progress';

type Bindings = {
  DB: D1Database;
  BUCKET: R2Bucket;
  JWT_SECRET: string;
  RESEND_API_KEY?: string;
  EMAIL_FROM?: string;
  AI_PROVIDER_KEY?: string;
  CF_ACCOUNT_ID?: string;
  CF_STREAM_CUSTOMER?: string;
};

const admin = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en } };
}

/** فقط Super Admin. در صورت مجاز، شناسه را برمی‌گرداند؛ در غیر این صورت null. */
async function requireAdmin(c: any): Promise<string | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub'] || p['role'] !== 'super_admin') return null;
  return p['sub'] as string;
}

// ────────────────────────────── کاربران ─────────────────────────────────────

admin.get('/users', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const role = c.req.query('role');
  const q = (c.req.query('q') ?? '').trim();
  const clauses: string[] = ["status != 'deleted'"];
  const binds: any[] = [];
  if (role) {
    clauses.push('role = ?');
    binds.push(role);
  }
  if (q) {
    clauses.push('(first_name LIKE ? OR last_name LIKE ? OR email LIKE ?)');
    binds.push(`%${q}%`, `%${q}%`, `%${q}%`);
  }
  const { results } = await c.env.DB.prepare(
    `SELECT id, email, first_name, last_name, role, status, email_verified, avatar_url, phone, specialty, bio, created_at FROM users
     WHERE ${clauses.join(' AND ')} ORDER BY created_at DESC LIMIT 500`,
  )
    .bind(...binds)
    .all<any>();
  const users = results.map((u) => ({
    id: u.id,
    name: `${u.first_name} ${u.last_name}`.trim(),
    email: u.email,
    role: u.role,
    suspended: u.status !== 'active',
    emailVerified: u.email_verified === 1,
    avatarUrl: u.avatar_url,
    phone: u.phone ?? '',
    specialty: u.specialty ?? '',
    bio: u.bio ?? '',
    createdAt: u.created_at,
  }));
  return c.json({ users });
});

admin.patch('/users/:id/toggle-suspend', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const u = await c.env.DB.prepare('SELECT status FROM users WHERE id = ?')
    .bind(id)
    .first<{ status: string }>();
  if (!u) return c.json(fail('NOT_FOUND', 'کاربر یافت نشد', 'User not found'), 404);
  const next = u.status === 'active' ? 'suspended' : 'active';
  await c.env.DB.prepare("UPDATE users SET status = ?, updated_at = datetime('now') WHERE id = ?")
    .bind(next, id)
    .run();
  return c.json({ success: true, status: next });
});

admin.patch('/users/:id', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  const status = b?.status;
  if (!status || !['active', 'suspended', 'deleted'].includes(status)) {
    return c.json(fail('BAD_REQUEST', 'وضعیت نامعتبر', 'Invalid status'), 400);
  }
  await c.env.DB.prepare("UPDATE users SET status = ?, updated_at = datetime('now') WHERE id = ?")
    .bind(status, c.req.param('id'))
    .run();
  return c.json({ success: true });
});

// ─────────────────────────── کدهای دعوت (بخش ۳ب.۳) ──────────────────────────

admin.get('/invite-codes', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const type = c.req.query('type');
  const status = c.req.query('status');
  const clauses: string[] = ['1=1'];
  const binds: any[] = [];
  if (type) {
    clauses.push('type = ?');
    binds.push(type);
  }
  if (status) {
    clauses.push('status = ?');
    binds.push(status);
  }
  const { results } = await c.env.DB.prepare(
    `SELECT * FROM invite_codes WHERE ${clauses.join(' AND ')} ORDER BY created_at DESC LIMIT 500`,
  )
    .bind(...binds)
    .all<any>();
  return c.json({ inviteCodes: results.map(codeJson) });
});

admin.post('/invite-codes/bulk-generate', async (c) => {
  const adminId = await requireAdmin(c);
  if (!adminId) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const b = await c.req.json<{ type?: string; count?: number; batchLabel?: string }>().catch(() => null);
  const type = b?.type === 'instructor' ? 'instructor' : 'student';
  const count = Math.min(Math.max(Number(b?.count ?? 1), 1), 100);
  const batchLabel = String(b?.batchLabel ?? '');
  const prefix = type === 'instructor' ? 'TCH' : 'STU';
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  const stmts = [];
  const created: string[] = [];
  for (let i = 0; i < count; i++) {
    let code = `${prefix}-`;
    for (let k = 0; k < 6; k++) code += chars[Math.floor(Math.random() * chars.length)];
    created.push(code);
    stmts.push(
      c.env.DB.prepare(
        "INSERT INTO invite_codes (id, code, type, batch_label, status, issued_by_admin_id) VALUES (?, ?, ?, ?, 'unused', ?)",
      ).bind(uid(), code, type, batchLabel, adminId),
    );
  }
  await c.env.DB.batch(stmts);
  return c.json({ success: true, count, codes: created }, 201);
});

admin.patch('/invite-codes/:id/revoke', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  await c.env.DB.prepare("UPDATE invite_codes SET status = 'revoked' WHERE id = ? AND status = 'unused'")
    .bind(c.req.param('id'))
    .run();
  return c.json({ success: true });
});

function codeJson(r: any) {
  return {
    id: r.id,
    code: r.code,
    type: r.type,
    batchLabel: r.batch_label,
    status: r.status,
    usedByUserId: r.used_by_user_id,
    usedAt: r.used_at,
    expiresAt: r.expires_at,
    createdAt: r.created_at,
  };
}

// ─────────────────────── آمار داشبورد مدیر (بخش ۱۵.۱ — KPI) ─────────────────
admin.get('/dashboard/stats', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const one = async (sql: string, ...b: any[]) => {
    const r = await c.env.DB.prepare(sql).bind(...b).first<{ n: number }>();
    return r?.n ?? 0;
  };
  const totalStudents = await one("SELECT COUNT(*) AS n FROM users WHERE role='student' AND status='active'");
  const activeToday = await one(
    `SELECT COUNT(DISTINCT uid) AS n FROM (
       SELECT user_id AS uid FROM student_lesson_views WHERE date(viewed_at)=date('now')
       UNION SELECT user_id AS uid FROM exam_attempts WHERE date(submitted_at)=date('now'))`,
  );
  const atRisk = await one(
    `SELECT COUNT(*) AS n FROM users u WHERE u.role='student' AND u.status='active'
       AND u.created_at <= date('now','-5 days')
       AND NOT EXISTS (SELECT 1 FROM student_lesson_views v WHERE v.user_id=u.id AND v.viewed_at>=date('now','-5 days'))
       AND NOT EXISTS (SELECT 1 FROM exam_attempts a WHERE a.user_id=u.id AND a.submitted_at>=date('now','-5 days'))`,
  );
  const avgRow = await c.env.DB.prepare('SELECT AVG(score_percent) AS a FROM exam_attempts').first<{ a: number | null }>();
  const { results: dist } = await c.env.DB.prepare(
    "SELECT current_grade AS g, COUNT(*) AS n FROM users WHERE role='student' AND status='active' AND current_grade IS NOT NULL GROUP BY current_grade",
  ).all<{ g: number; n: number }>();
  const gradeDistribution: Record<string, number> = {};
  for (const r of dist) gradeDistribution[String(r.g)] = r.n;
  return c.json({
    totalStudents,
    activeToday,
    atRiskCount: atRisk,
    avgScorePercent: avgRow?.a != null ? Math.round(avgRow.a * 10) / 10 : 0,
    gradeDistribution,
  });
});

// ─────────────────────── سلامت زندهٔ سیستم (پایش مدیر) ──────────────────────
// دیتابیس (D1) و فضای ذخیره‌سازی (R2) به‌صورت واقعی و زنده تست می‌شوند؛
// خدمات جانبی (AI، ایمیل، پخش زنده) فقط از نظر «پیکربندی‌شده بودن» بررسی
// می‌شوند تا هزینه/تأخیر تماس واقعی با آن‌ها به این Endpoint تحمیل نشود.
// شناسهٔ هر بررسی (`id`) عمداً رشته‌ای و باز است — می‌توان بعداً بررسی‌های
// جدید اضافه کرد بدون نیاز به تغییر کلاینت (اپ آن‌ها را با آیکون/برچسب
// پیش‌فرض نمایش می‌دهد).
type HealthCheck = {
  id: string;
  status: 'ok' | 'warning' | 'error';
  latencyMs?: number;
  detail_fa?: string;
  detail_en?: string;
};

admin.get('/system-health', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);

  const checks: HealthCheck[] = [];

  // API — اگر به این‌جا رسیده‌ایم، خود سرور در دسترس است.
  checks.push({ id: 'api', status: 'ok', latencyMs: 0 });

  // دیتابیس D1 — یک پرس‌وجوی سبک و واقعی.
  {
    const start = Date.now();
    try {
      await c.env.DB.prepare('SELECT 1 AS ok').first();
      checks.push({ id: 'database', status: 'ok', latencyMs: Date.now() - start });
    } catch {
      checks.push({
        id: 'database',
        status: 'error',
        latencyMs: Date.now() - start,
        detail_fa: 'اتصال به دیتابیس D1 برقرار نشد',
        detail_en: 'Could not connect to the D1 database',
      });
    }
  }

  // فضای ذخیره‌سازی R2.
  {
    const start = Date.now();
    try {
      await c.env.BUCKET.list({ limit: 1 });
      checks.push({ id: 'storage', status: 'ok', latencyMs: Date.now() - start });
    } catch {
      checks.push({
        id: 'storage',
        status: 'error',
        latencyMs: Date.now() - start,
        detail_fa: 'اتصال به فضای ذخیره‌سازی R2 برقرار نشد',
        detail_en: 'Could not connect to the R2 storage bucket',
      });
    }
  }

  // احراز هویت — بودن JWT_SECRET.
  checks.push(
    c.env.JWT_SECRET
      ? { id: 'auth', status: 'ok' }
      : {
          id: 'auth',
          status: 'error',
          detail_fa: 'JWT_SECRET تنظیم نشده است',
          detail_en: 'JWT_SECRET is not configured',
        },
  );

  // معلم هوشمند (LLM) — فقط بررسی پیکربندی، نه تماس واقعی.
  checks.push(
    c.env.AI_PROVIDER_KEY
      ? { id: 'aiTeacher', status: 'ok' }
      : {
          id: 'aiTeacher',
          status: 'warning',
          detail_fa: 'AI_PROVIDER_KEY تنظیم نشده — معلم هوشمند غیرفعال است',
          detail_en: 'AI_PROVIDER_KEY is not configured — the AI teacher is disabled',
        },
  );

  // ایمیل (Resend) — فقط بررسی پیکربندی.
  checks.push(
    c.env.RESEND_API_KEY
      ? { id: 'email', status: 'ok' }
      : {
          id: 'email',
          status: 'warning',
          detail_fa: 'RESEND_API_KEY تنظیم نشده — ارسال ایمیل غیرفعال است',
          detail_en: 'RESEND_API_KEY is not configured — email sending is disabled',
        },
  );

  // پخش زندهٔ سمینار (Cloudflare Stream) — نبودش خطرناک نیست چون اپ به‌صورت
  // خودکار به لینک دستی/اتاق داخلی برمی‌گردد.
  checks.push(
    c.env.CF_ACCOUNT_ID && c.env.CF_STREAM_CUSTOMER
      ? { id: 'liveStream', status: 'ok' }
      : {
          id: 'liveStream',
          status: 'warning',
          detail_fa: 'Cloudflare Stream پیکربندی نشده — به لینک دستی جلسه بازمی‌گردد',
          detail_en: 'Cloudflare Stream is not configured — falls back to a manual meeting link',
        },
  );

  const hasError = checks.some((x) => x.status === 'error');
  const hasWarning = checks.some((x) => x.status === 'warning');
  const overallStatus = hasError ? 'down' : hasWarning ? 'degraded' : 'operational';

  return c.json({
    success: true,
    timestamp: new Date().toISOString(),
    overallStatus,
    checks,
  });
});

// ─────────────────────── گزارش خلاصهٔ پلتفرم (بخش ۱۵.۳) ──────────────────────
// همهٔ اعداد از دادهٔ واقعی D1 محاسبه می‌شوند (نه مقادیر ثابت).

admin.get('/reports/summary', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);

  const one = async (sql: string, ...binds: any[]) => {
    const r = await c.env.DB.prepare(sql).bind(...binds).first<{ n: number }>();
    return r?.n ?? 0;
  };

  const students = await one("SELECT COUNT(*) AS n FROM users WHERE role='student' AND status='active'");
  const instructors = await one("SELECT COUNT(*) AS n FROM users WHERE role='seminar_instructor' AND status='active'");
  const parentsCount = await one("SELECT COUNT(*) AS n FROM users WHERE role='parent'");
  const certs = await one('SELECT COUNT(*) AS n FROM certificates');
  const attempts = await one('SELECT COUNT(*) AS n FROM exam_attempts');
  const seminarsActive = await one("SELECT COUNT(*) AS n FROM seminars WHERE status IN ('published','registrationClosed','live')");
  const unusedCodes = await one("SELECT COUNT(*) AS n FROM invite_codes WHERE status='unused'");
  const avgRow = await c.env.DB.prepare('SELECT AVG(score_percent) AS a FROM exam_attempts')
    .first<{ a: number | null }>();
  const avgScore = avgRow?.a != null ? Math.round(avgRow.a * 10) / 10 : 0;

  // دانش‌آموزان در معرض خطر: فعال ولی بدون هیچ فعالیتی در ۵ روز اخیر.
  const atRisk = await one(
    `SELECT COUNT(*) AS n FROM users u WHERE u.role='student' AND u.status='active'
       AND u.created_at <= date('now','-5 days')
       AND NOT EXISTS (SELECT 1 FROM student_lesson_views v WHERE v.user_id=u.id AND v.viewed_at>=date('now','-5 days'))
       AND NOT EXISTS (SELECT 1 FROM exam_attempts a WHERE a.user_id=u.id AND a.submitted_at>=date('now','-5 days'))`,
  );

  const rows = [
    { label: 'تعداد کل دانش‌آموزان', value: `${students}` },
    { label: 'تعداد استادان', value: `${instructors}` },
    { label: 'تعداد والدین', value: `${parentsCount}` },
    { label: 'میانگین نمرهٔ امتحانات', value: `${avgScore}%` },
    { label: 'تعداد امتحانات ثبت‌شده', value: `${attempts}` },
    { label: 'گواهی‌نامه‌های صادرشده', value: `${certs}` },
    { label: 'سمینارهای فعال', value: `${seminarsActive}` },
    { label: 'کدهای دعوت استفاده‌نشده', value: `${unusedCodes}` },
    { label: 'دانش‌آموزان در معرض خطر', value: `${atRisk}` },
  ];
  return c.json({ rows });
});

// ─────────────────────── صف بازبینی ایمنی (بخش ۱۵.۵) ────────────────────────
// موارد ذخیره‌شده + موارد at-risk سنتزشده از فعالیت واقعی.

admin.get('/safety-queue', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);

  const { results: stored } = await c.env.DB.prepare(
    'SELECT * FROM safety_events ORDER BY detected_at DESC',
  ).all<any>();
  const storedStudentIds = new Set(stored.filter((s) => s.type === 'atRisk').map((s) => s.student_id));

  // at-risk سنتزشده: دانش‌آموز فعال بدون فعالیت ۵ روز اخیر که هنوز موردی ثبت نشده.
  const { results: risky } = await c.env.DB.prepare(
    `SELECT u.id, u.first_name, u.last_name, u.current_grade FROM users u
       WHERE u.role='student' AND u.status='active' AND u.created_at <= date('now','-5 days')
       AND NOT EXISTS (SELECT 1 FROM student_lesson_views v WHERE v.user_id=u.id AND v.viewed_at>=date('now','-5 days'))
       AND NOT EXISTS (SELECT 1 FROM exam_attempts a WHERE a.user_id=u.id AND a.submitted_at>=date('now','-5 days'))
       LIMIT 100`,
  ).all<{ id: string; first_name: string; last_name: string; current_grade: number | null }>();

  const items = stored.map(safetyJson);
  for (const r of risky) {
    if (storedStudentIds.has(r.id)) continue;
    items.push({
      id: `atrisk:${r.id}`,
      type: 'atRisk',
      summary: 'دانش‌آموز بیش از ۵ روز فعالیتی نداشته است',
      highPriority: true,
      status: 'open',
      studentName: `${r.first_name} ${r.last_name}`.trim(),
      studentGrade: r.current_grade ? `صنف ${r.current_grade}` : '',
      source: 'سیستم حاضری',
      detectedAt: new Date().toISOString(),
      detail: 'هیچ بازدید درس یا تلاش امتحانی در ۵ روز گذشته ثبت نشده است (بخش ۹.۴).',
      triggerReason: 'عدم فعالیت ۵ روزه',
    });
  }
  return c.json({ items });
});

admin.patch('/safety-queue/:id/resolve', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  const status = b?.status ?? 'reviewed';
  if (!['open', 'reviewed', 'dismissed', 'escalated'].includes(status)) {
    return c.json(fail('BAD_REQUEST', 'وضعیت نامعتبر', 'Invalid status'), 400);
  }
  const id = c.req.param('id');
  if (id.startsWith('atrisk:')) {
    // مورد سنتزشده → به‌عنوان یک رویداد ذخیره‌شده با تصمیم مدیر ثبت می‌شود.
    const studentId = id.slice('atrisk:'.length);
    const u = await c.env.DB.prepare('SELECT first_name, last_name, current_grade FROM users WHERE id = ?')
      .bind(studentId)
      .first<{ first_name: string; last_name: string; current_grade: number | null }>();
    await c.env.DB.prepare(
      `INSERT INTO safety_events (id, type, summary, high_priority, status, student_id, student_name, student_grade, source, trigger_reason)
         VALUES (?, 'atRisk', ?, 1, ?, ?, ?, ?, 'سیستم حاضری', 'عدم فعالیت ۵ روزه')
         ON CONFLICT(id) DO UPDATE SET status=excluded.status`,
    )
      .bind(
        id,
        'دانش‌آموز بیش از ۵ روز فعالیتی نداشته است',
        status,
        studentId,
        u ? `${u.first_name} ${u.last_name}`.trim() : '',
        u?.current_grade ? `صنف ${u.current_grade}` : '',
      )
      .run();
  } else {
    await c.env.DB.prepare('UPDATE safety_events SET status = ? WHERE id = ?').bind(status, id).run();
  }
  return c.json({ success: true });
});

function safetyJson(r: any) {
  return {
    id: r.id,
    type: r.type,
    summary: r.summary,
    highPriority: r.high_priority === 1,
    status: r.status,
    studentName: r.student_name,
    studentGrade: r.student_grade,
    source: r.source,
    detectedAt: r.detected_at,
    detail: r.detail,
    triggerReason: r.trigger_reason,
  };
}

// ═══════════════════════ مدیریت تفصیلی شاگرد (بخش ۱۵.۲) ═══════════════════════
// همهٔ مقادیر (میانگین، حاضری، رتبه، ریسک، گزارش AI) در سرور از دادهٔ واقعی
// محاسبه می‌شوند — کلاینت فقط نمایش می‌دهد (اصل بخش ۴).

const PAGE_SIZE = 20;

/** سطح ریسک از میانگین نمره و نرخ حاضری (heuristic سرور). */
function riskLevel(gradeAvg: number, attendance: number): string {
  if (gradeAvg < 50 || attendance < 40) return 'high';
  if (gradeAvg < 60 || attendance < 60) return 'medium';
  if (gradeAvg < 75 || attendance < 75) return 'low';
  return 'none';
}

/** نرخ حاضری ۱۴ روزهٔ یک کاربر از فعالیت واقعی (بازدید درس/تلاش امتحان). */
async function attendanceRateOf(db: D1Database, userId: string): Promise<number> {
  const { results } = await db
    .prepare(
      `SELECT DISTINCT d FROM (
         SELECT date(viewed_at) AS d FROM student_lesson_views
         WHERE user_id = ? AND viewed_at >= date('now','-13 days')
         UNION
         SELECT date(submitted_at) AS d FROM exam_attempts
         WHERE user_id = ? AND submitted_at >= date('now','-13 days')
       )`,
    )
    .bind(userId, userId)
    .all<{ d: string }>();
  return Math.round((results.length / 14) * 1000) / 10;
}

/** ردیف خلاصهٔ شاگرد از یک رکورد users + محاسبات. */
async function studentSummary(db: D1Database, u: any): Promise<Record<string, unknown>> {
  const avgRow = await db
    .prepare(
      'SELECT AVG(score_percent) AS avg, COUNT(*) AS n, MAX(submitted_at) AS last FROM exam_attempts WHERE user_id = ?',
    )
    .bind(u.id)
    .first<{ avg: number | null; n: number; last: string | null }>();
  const lastView = await db
    .prepare('SELECT MAX(viewed_at) AS last FROM student_lesson_views WHERE user_id = ?')
    .bind(u.id)
    .first<{ last: string | null }>();
  const gradeAverage = Math.round((avgRow?.avg ?? 0) * 10) / 10;
  const attendanceRate = await attendanceRateOf(db, u.id);
  const lastActive = [avgRow?.last, lastView?.last].filter(Boolean).sort().pop() ?? null;
  return {
    id: u.id,
    full_name: `${u.first_name} ${u.last_name}`.trim(),
    avatar_url: u.avatar_url ?? null,
    current_grade: u.current_grade ?? 7,
    province: u.province ?? '',
    status: u.status,
    risk_level: riskLevel(gradeAverage, attendanceRate),
    grade_average: gradeAverage,
    attendance_rate: attendanceRate,
    last_active_at: lastActive,
  };
}

admin.get('/students', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const q = (c.req.query('q') ?? '').trim();
  const grade = c.req.query('grade');
  const province = c.req.query('province');
  const status = c.req.query('status');
  const page = Math.max(1, parseInt(c.req.query('page') ?? '1', 10) || 1);

  const clauses: string[] = ["role = 'student'", "status != 'deleted'"];
  const binds: any[] = [];
  if (q) {
    clauses.push('(first_name LIKE ? OR last_name LIKE ? OR email LIKE ?)');
    binds.push(`%${q}%`, `%${q}%`, `%${q}%`);
  }
  if (grade) {
    clauses.push('current_grade = ?');
    binds.push(Number(grade));
  }
  if (province) {
    clauses.push('province = ?');
    binds.push(province);
  }
  if (status && ['active', 'suspended', 'pending_verification'].includes(status)) {
    clauses.push('status = ?');
    binds.push(status);
  }
  const where = clauses.join(' AND ');

  const totalRow = await c.env.DB.prepare(`SELECT COUNT(*) AS n FROM users WHERE ${where}`)
    .bind(...binds)
    .first<{ n: number }>();
  const total = totalRow?.n ?? 0;

  const { results } = await c.env.DB.prepare(
    `SELECT id, first_name, last_name, avatar_url, current_grade, province, status FROM users
       WHERE ${where} ORDER BY created_at DESC LIMIT ? OFFSET ?`,
  )
    .bind(...binds, PAGE_SIZE, (page - 1) * PAGE_SIZE)
    .all<any>();

  let items = await Promise.all(results.map((u) => studentSummary(c.env.DB, u)));
  // فیلتر at_risk فقط پس از محاسبهٔ ریسک قابل اعمال است.
  if (c.req.query('at_risk') === 'true') {
    items = items.filter((i) => i.risk_level === 'high' || i.risk_level === 'medium');
  }
  return c.json({ items, total, page, page_size: PAGE_SIZE });
});

// جزئیات تحصیلی شاگرد — پیشرفت هر مضمون از lib/progress.ts (منبع واحد) می‌آید
// تا با داشبورد خود شاگرد و داشبورد والد دقیقاً یکسان باشد؛ فقط میانگین
// کوییز/امتحان و وضعیت تفصیلی (قبول/مردود) مختص این گزارش مدیریتی است.
admin.get('/students/:id', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const u = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(id).first<any>();
  if (!u || u.role !== 'student') {
    return c.json(fail('NOT_FOUND', 'شاگرد یافت نشد', 'Student not found'), 404);
  }
  const grade = u.current_grade ?? 7;

  // پیشرفت هر مضمون (منبع واحد) + میانگین کوییز/امتحان جداگانه از داده واقعی.
  const subjectsProgress = await getSubjectProgressList(c.env.DB, id, grade);
  const { results: quizExamRows } = await c.env.DB.prepare(
    `SELECT s.id,
       (SELECT AVG(a.score_percent) FROM exam_attempts a JOIN exams e ON e.id=a.exam_id
          WHERE a.user_id=? AND e.subject_id=s.id AND e.type IN ('daily_quiz','homework')) AS quiz_avg,
       (SELECT AVG(a.score_percent) FROM exam_attempts a JOIN exams e ON e.id=a.exam_id
          WHERE a.user_id=? AND e.subject_id=s.id AND e.type IN ('monthly','final')) AS exam_avg
       FROM subjects s ORDER BY s.order_index`,
  )
    .bind(id, id)
    .all<{ id: string; quiz_avg: number | null; exam_avg: number | null }>();
  const quizExamMap = new Map(quizExamRows.map((r) => [r.id, r]));

  const subjects = subjectsProgress.map((sp) => {
    const qe = quizExamMap.get(sp.subjectId);
    const quiz = qe?.quiz_avg != null ? Math.round(qe.quiz_avg * 10) / 10 : null;
    const exam = qe?.exam_avg != null ? Math.round(qe.exam_avg * 10) / 10 : null;
    const scores = [quiz, exam].filter((x): x is number => x != null);
    const finalScore = scores.length ? Math.round((scores.reduce((a, b) => a + b, 0) / scores.length) * 10) / 10 : null;
    let status = 'inProgress';
    if (sp.viewedLessons === 0) status = 'locked';
    else if (sp.percent >= 100 && (finalScore ?? 0) >= 60) status = 'completed';
    else if (finalScore != null && finalScore < 50) status = 'failed';
    return {
      subject_id: sp.subjectId,
      subject_name: sp.nameFa,
      status,
      progress_percent: sp.percent,
      final_score: finalScore,
      quiz_average: quiz,
      exam_average: exam,
      completed_lessons: sp.viewedLessons,
      total_lessons: sp.totalLessons,
    };
  });

  // حاضری ۳۰ روزه.
  const { results: actDays } = await c.env.DB.prepare(
    `SELECT DISTINCT d FROM (
       SELECT date(viewed_at) AS d FROM student_lesson_views WHERE user_id=? AND viewed_at >= date('now','-29 days')
       UNION SELECT date(submitted_at) AS d FROM exam_attempts WHERE user_id=? AND submitted_at >= date('now','-29 days')
     )`,
  )
    .bind(id, id)
    .all<{ d: string }>();
  const activeSet = new Set(actDays.map((r) => r.d));
  const last30: { date: string; present: boolean }[] = [];
  let present = 0;
  const now = Date.now();
  for (let i = 29; i >= 0; i--) {
    const day = new Date(now - i * 86400000);
    const iso = day.toISOString().slice(0, 10);
    const p = activeSet.has(iso);
    if (p) present++;
    last30.push({ date: day.toISOString(), present: p });
  }
  const rate = Math.round((present / 30) * 1000) / 10;

  // پیوندهای والد.
  const { results: links } = await c.env.DB.prepare(
    'SELECT id, parent_name, status FROM parent_student_links WHERE student_user_id = ?',
  )
    .bind(id)
    .all<any>();

  const certCount = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM certificates WHERE student_id = ?')
    .bind(id)
    .first<{ n: number }>();
  const examCount = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM exam_attempts WHERE user_id = ?')
    .bind(id)
    .first<{ n: number }>();

  // رتبه در صنف بر اساس میانگین نمره.
  const myAvgRow = await c.env.DB.prepare('SELECT AVG(score_percent) AS a FROM exam_attempts WHERE user_id = ?')
    .bind(id)
    .first<{ a: number | null }>();
  const myAvg = myAvgRow?.a ?? 0;
  const classSizeRow = await c.env.DB.prepare(
    "SELECT COUNT(*) AS n FROM users WHERE role='student' AND status='active' AND current_grade = ?",
  )
    .bind(grade)
    .first<{ n: number }>();
  const higherRow = await c.env.DB.prepare(
    `SELECT COUNT(*) AS n FROM (
       SELECT u2.id, AVG(a.score_percent) AS a FROM users u2
       LEFT JOIN exam_attempts a ON a.user_id = u2.id
       WHERE u2.role='student' AND u2.status='active' AND u2.current_grade = ?
       GROUP BY u2.id HAVING a > ?
     )`,
  )
    .bind(grade, myAvg)
    .first<{ n: number }>();

  const summary = await studentSummary(c.env.DB, u);

  // امتیاز فعالیت (Gamification) — همان امتیازی که در خانهٔ شاگرد نمایش داده می‌شود.
  const points = await getPointsSummary(c.env.DB, id);

  return c.json({
    summary,
    email: u.email,
    phone: u.phone ?? '',
    birth_date: u.date_of_birth ?? '2010-01-01',
    registered_at: u.created_at,
    subjects,
    attendance: {
      present_days: present,
      absent_days: 30 - present,
      rate,
      below_threshold: rate < 75,
      last_30_days: last30,
    },
    parent_links: links.map((l) => ({ link_id: l.id, parent_name: l.parent_name, status: l.status })),
    certificates_count: certCount?.n ?? 0,
    ai_conversations_count: 0,
    exams_taken: examCount?.n ?? 0,
    class_rank: (higherRow?.n ?? 0) + 1,
    class_size: classSizeRow?.n ?? 1,
    points_total: points.totalPoints,
    points_level: points.level,
    points_level_title_fa: points.levelTitleFa,
  });
});

admin.get('/students/:id/ai-report', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const u = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?').bind(id).first<any>();
  if (!u) return c.json(fail('NOT_FOUND', 'شاگرد یافت نشد', 'Student not found'), 404);
  const grade = u.current_grade ?? 7;

  // پیشرفت کلی از منبع واحد (lib/progress.ts) — همان عددی که در داشبورد
  // شاگرد و والد به‌عنوان «پیشرفت کلی» نمایش داده می‌شود.
  const subjectsProgress = await getSubjectProgressList(c.env.DB, id, grade);
  const overall = averagePercent(subjectsProgress);

  // روند: میانگین ۵ تلاش اخیر در برابر ۵ تلاش قبل‌تر.
  const { results: recent } = await c.env.DB.prepare(
    'SELECT score_percent FROM exam_attempts WHERE user_id = ? ORDER BY submitted_at DESC LIMIT 10',
  )
    .bind(id)
    .all<{ score_percent: number }>();
  const newer = recent.slice(0, 5).map((r) => r.score_percent);
  const older = recent.slice(5, 10).map((r) => r.score_percent);
  const avg = (a: number[]) => (a.length ? a.reduce((x, y) => x + y, 0) / a.length : 0);
  const newerAvg = avg(newer);
  const olderAvg = avg(older);
  let trend = 'stable';
  if (older.length && newerAvg - olderAvg > 5) trend = 'improving';
  else if (older.length && olderAvg - newerAvg > 5) trend = 'declining';

  const attendance = await attendanceRateOf(c.env.DB, id);
  const scoreAvg = recent.length ? Math.round(avg(recent.map((r) => r.score_percent)) * 10) / 10 : 0;
  const stress = attendance < 40 || scoreAvg < 40 ? 'high' : attendance < 65 || scoreAvg < 60 ? 'medium' : 'low';
  const engagement = Math.round(((overall + attendance) / 2) * 10) / 10;

  // قوت‌ها و مشکلات بر اساس مضامین.
  const { results: subjPerf } = await c.env.DB.prepare(
    `SELECT s.name_fa, AVG(a.score_percent) AS avg FROM exam_attempts a
       JOIN exams e ON e.id=a.exam_id JOIN subjects s ON s.id=e.subject_id
       WHERE a.user_id = ? GROUP BY s.id ORDER BY avg DESC`,
  )
    .bind(id)
    .all<{ name_fa: string; avg: number }>();
  const strengths = subjPerf.filter((s) => s.avg >= 70).slice(0, 3).map((s) => `عملکرد قوی در ${s.name_fa}`);
  const concerns = subjPerf.filter((s) => s.avg < 50).slice(0, 3).map((s) => `ضعف در ${s.name_fa} (میانگین ${Math.round(s.avg)}٪)`);
  if (attendance < 60) concerns.push(`حاضری پایین (${attendance}٪) — نیاز به پیگیری`);
  const recommendations: string[] = [];
  if (concerns.length) recommendations.push('تمرکز بر مضامین ضعیف با تمرین بیشتر و پشتیبانی معلم هوشمند');
  if (attendance < 75) recommendations.push('تشویق به فعالیت منظم روزانه برای بهبود حاضری');
  if (!strengths.length && !concerns.length) recommendations.push('شروع فعالیت آموزشی — هنوز دادهٔ کافی ثبت نشده است');

  const subjectNotes = subjPerf.slice(0, 6).map((s) => ({
    subject_name: s.name_fa,
    note: s.avg >= 70 ? 'پیشرفت رضایت‌بخش' : s.avg >= 50 ? 'نیاز به تمرین بیشتر' : 'نیاز به توجه ویژه',
  }));

  return c.json({
    generated_at: new Date().toISOString(),
    overall_progress: overall,
    trend,
    stress_level: stress,
    engagement_score: engagement,
    strengths: strengths.length ? strengths : ['هنوز داده کافی برای شناسایی نقاط قوت نیست'],
    concerns,
    recommendations,
    subject_notes: subjectNotes,
  });
});

admin.patch('/students/:id/status', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const b = await c.req.json<{ status?: string; reason?: string }>().catch(() => null);
  const status = b?.status;
  if (!status || !['active', 'suspended', 'deleted'].includes(status)) {
    return c.json(fail('BAD_REQUEST', 'وضعیت نامعتبر', 'Invalid status'), 400);
  }
  const u = await c.env.DB.prepare('SELECT id FROM users WHERE id = ? AND role = ?')
    .bind(c.req.param('id'), 'student')
    .first<{ id: string }>();
  if (!u) return c.json(fail('NOT_FOUND', 'شاگرد یافت نشد', 'Student not found'), 404);
  await c.env.DB.prepare("UPDATE users SET status = ?, updated_at = datetime('now') WHERE id = ?")
    .bind(status, c.req.param('id'))
    .run();
  // در صورت تعلیق/حذف، همهٔ نشست‌های شاگرد باطل می‌شوند.
  if (status !== 'active') {
    await c.env.DB.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?')
      .bind(c.req.param('id'))
      .run();
  }
  return c.json({ success: true });
});

admin.post('/students/:id/password-reset-link', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const u = await c.env.DB.prepare('SELECT id, email, first_name FROM users WHERE id = ?')
    .bind(id)
    .first<{ id: string; email: string; first_name: string }>();
  if (!u) return c.json(fail('NOT_FOUND', 'شاگرد یافت نشد', 'Student not found'), 404);

  const code = randomSixDigitCode();
  const codeHash = await sha256B64Url(code);
  const expiresAt = new Date(Date.now() + 15 * 60_000).toISOString();
  await c.env.DB.batch([
    c.env.DB.prepare("UPDATE email_tokens SET used = 1 WHERE user_id = ? AND type = 'reset'").bind(u.id),
    c.env.DB.prepare(
      "INSERT INTO email_tokens (id, user_id, type, token_hash, expires_at) VALUES (?, ?, 'reset', ?, ?)",
    ).bind(crypto.randomUUID(), u.id, codeHash, expiresAt),
  ]);
  c.executionCtx.waitUntil(
    sendEmail(
      c.env,
      u.email,
      'کد بازیابی رمز عبور — مکتب دیجیتال دختران افغانستان',
      resetEmailHtml(u.first_name, code),
    ),
  );
  return c.json({ success: true, message_fa: 'کد بازیابی به ایمیل شاگرد ارسال شد' });
});

// ═══════════════ نصاب هوشمند: انتشار فصل‌های شناسایی‌شده از یک کتاب ═══════════
// کلاینت (هنگام آپلود کتاب توسط مدیر) عناوین فصل را با شناسایی هوشمند
// (اندازهٔ فونت/الگوی «فصل N» در PDF) استخراج می‌کند و اینجا هر فصل را به یک
// رکورد `chapters` + دقیقاً یک `lessons` (با کل متن همان فصل) تبدیل می‌کند.
// تکمیل آن یک درس = تکمیل فصل → پایهٔ قفل‌گشایی ترتیبی فصل بعدی (lib/progress.ts).
// درخواست دوباره برای همان bookId، فصل‌های قبلیِ همان کتاب را جایگزین می‌کند.
admin.post('/curriculum/subjects/:subjectId/publish-chapters', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const subjectId = c.req.param('subjectId');
  const b = await c.req
    .json<{ bookId?: string; gradeId?: number; chapters?: { title?: string; content?: string }[] }>()
    .catch(() => null);
  const bookId = String(b?.bookId ?? '').trim();
  const gradeId = Number(b?.gradeId ?? 0);
  const chapters = Array.isArray(b?.chapters) ? b!.chapters! : [];
  if (!bookId || !gradeId || !chapters.length) {
    return c.json(fail('BAD_REQUEST', 'شناسهٔ کتاب، صنف و فهرست فصل‌ها لازم است', 'Missing fields'), 400);
  }
  const subject = await c.env.DB.prepare('SELECT id FROM subjects WHERE id = ?').bind(subjectId).first();
  if (!subject) return c.json(fail('NOT_FOUND', 'مضمون یافت نشد', 'Subject not found'), 404);

  // جایگزینی کامل: فصل‌های قبلیِ همین کتاب (و درس‌ها/بازدیدها/تکمیل‌های وابسته) حذف می‌شوند.
  const { results: oldChapters } = await c.env.DB.prepare('SELECT id FROM chapters WHERE source_book_id = ?')
    .bind(bookId)
    .all<{ id: string }>();
  if (oldChapters.length) {
    const chIds = oldChapters.map((r) => r.id);
    const chPh = chIds.map(() => '?').join(',');
    const { results: oldLessons } = await c.env.DB.prepare(`SELECT id FROM lessons WHERE chapter_id IN (${chPh})`)
      .bind(...chIds)
      .all<{ id: string }>();
    if (oldLessons.length) {
      const lsIds = oldLessons.map((r) => r.id);
      const lsPh = lsIds.map(() => '?').join(',');
      await c.env.DB.prepare(`DELETE FROM student_lesson_views WHERE lesson_id IN (${lsPh})`).bind(...lsIds).run();
      await c.env.DB.prepare(`DELETE FROM lessons WHERE id IN (${lsPh})`).bind(...lsIds).run();
    }
    await c.env.DB.prepare(`DELETE FROM student_chapter_completions WHERE chapter_id IN (${chPh})`).bind(...chIds).run();
    await c.env.DB.prepare(`DELETE FROM chapters WHERE id IN (${chPh})`).bind(...chIds).run();
  }

  // درج فصل‌های تازه — هر فصل = یک chapter + دقیقاً یک lesson با کل متن فصل.
  const stmts: any[] = [];
  const createdChapterIds: string[] = [];
  chapters.forEach((ch, i) => {
    const title = String(ch?.title ?? `فصل ${i + 1}`).trim().slice(0, 200) || `فصل ${i + 1}`;
    const content = String(ch?.content ?? '');
    const chapterId = `ch_${bookId}_${i}`;
    const lessonId = `ls_${bookId}_${i}`;
    // برآورد زمان مطالعه از طول متن (هر ~۵۰۰ نویسه ≈ ۱ دقیقه)، بین ۵ تا ۶۰ دقیقه.
    const minutes = Math.min(60, Math.max(5, Math.round(content.length / 500)));
    createdChapterIds.push(chapterId);
    stmts.push(
      c.env.DB.prepare(
        'INSERT INTO chapters (id, grade_number, subject_id, title_fa, order_index, status, source_book_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
      ).bind(chapterId, gradeId, subjectId, title, i + 1, 'published', bookId),
    );
    stmts.push(
      c.env.DB.prepare(
        'INSERT INTO lessons (id, chapter_id, title_fa, estimated_minutes, order_index, content_body, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
      ).bind(lessonId, chapterId, title, minutes, 1, content, 'published'),
    );
  });
  await c.env.DB.batch(stmts);

  return c.json({ success: true, chaptersCreated: createdChapterIds.length, chapterIds: createdChapterIds }, 201);
});

export default admin;
