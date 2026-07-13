/**
 * routes/admin.ts — مدیریت کاربران و کدهای دعوت (بخش ۱۵.۲ و ۳ب.۳ سند).
 * فقط برای Super Admin (بررسی نقش از JWT).
 *
 * Endpointها (زیر `/api/v1/admin`):
 *   GET   /users?role=&q=
 *   PATCH /users/:id/toggle-suspend
 *   PATCH /users/:id                 body {status}
 *   GET   /invite-codes?type=&status=
 *   POST  /invite-codes/bulk-generate  body {type,count,batchLabel}
 *   PATCH /invite-codes/:id/revoke
 *   ── مدیریت تفصیلی شاگرد (بخش ۱۵.۲) ──
 *   GET   /students?q=&grade=&province=&status=&at_risk=&page=   لیست صفحه‌بندی‌شده
 *   GET   /students/:id                جزئیات کامل تحصیلی
 *   GET   /students/:id/ai-report      گزارش معلم هوشمند (محاسبه‌شده از داده واقعی)
 *   PATCH /students/:id/status         body {status, reason}
 *   POST  /students/:id/password-reset-link   ارسال کد بازیابی به ایمیل شاگرد
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import {
  sendEmail,
  resetEmailHtml,
  sha256B64Url,
  randomSixDigitCode,
} from '../lib/email';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  RESEND_API_KEY?: string;
  EMAIL_FROM?: string;
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
    `SELECT id, email, first_name, last_name, role, status, email_verified, avatar_url FROM users
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

admin.get('/students/:id', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const u = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(id).first<any>();
  if (!u || u.role !== 'student') {
    return c.json(fail('NOT_FOUND', 'شاگرد یافت نشد', 'Student not found'), 404);
  }
  const grade = u.current_grade ?? 7;

  // پیشرفت هر مضمون + میانگین کوییز/امتحان از داده واقعی.
  const { results: subs } = await c.env.DB.prepare(
    `SELECT s.id, s.name_fa,
       (SELECT COUNT(*) FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
          WHERE ch.subject_id=s.id AND ch.grade_number=? AND l.status='published' AND ch.status='published') AS total,
       (SELECT COUNT(*) FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
          JOIN student_lesson_views v ON v.lesson_id=l.id AND v.user_id=?
          WHERE ch.subject_id=s.id AND ch.grade_number=? AND l.status='published' AND ch.status='published') AS viewed,
       (SELECT AVG(a.score_percent) FROM exam_attempts a JOIN exams e ON e.id=a.exam_id
          WHERE a.user_id=? AND e.subject_id=s.id AND e.type IN ('daily_quiz','homework')) AS quiz_avg,
       (SELECT AVG(a.score_percent) FROM exam_attempts a JOIN exams e ON e.id=a.exam_id
          WHERE a.user_id=? AND e.subject_id=s.id AND e.type IN ('monthly','final')) AS exam_avg
     FROM subjects s ORDER BY s.order_index`,
  )
    .bind(grade, id, grade, id, id)
    .all<any>();

  const subjects = subs.map((r) => {
    const progress = r.total > 0 ? Math.round((r.viewed / r.total) * 1000) / 10 : 0;
    const quiz = r.quiz_avg != null ? Math.round(r.quiz_avg * 10) / 10 : null;
    const exam = r.exam_avg != null ? Math.round(r.exam_avg * 10) / 10 : null;
    const scores = [quiz, exam].filter((x): x is number => x != null);
    const finalScore = scores.length ? Math.round((scores.reduce((a, b) => a + b, 0) / scores.length) * 10) / 10 : null;
    let status = 'inProgress';
    if (r.viewed === 0) status = 'locked';
    else if (progress >= 100 && (finalScore ?? 0) >= 60) status = 'completed';
    else if (finalScore != null && finalScore < 50) status = 'failed';
    return {
      subject_id: r.id,
      subject_name: r.name_fa,
      status,
      progress_percent: progress,
      final_score: finalScore,
      quiz_average: quiz,
      exam_average: exam,
      completed_lessons: r.viewed,
      total_lessons: r.total,
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
  });
});

admin.get('/students/:id/ai-report', async (c) => {
  if (!(await requireAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const u = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?').bind(id).first<any>();
  if (!u) return c.json(fail('NOT_FOUND', 'شاگرد یافت نشد', 'Student not found'), 404);
  const grade = u.current_grade ?? 7;

  // پیشرفت کلی از نسبت دروس دیده‌شده.
  const prog = await c.env.DB.prepare(
    `SELECT
       (SELECT COUNT(*) FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
          WHERE ch.grade_number=? AND l.status='published' AND ch.status='published') AS total,
       (SELECT COUNT(*) FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
          JOIN student_lesson_views v ON v.lesson_id=l.id AND v.user_id=?
          WHERE ch.grade_number=? AND l.status='published' AND ch.status='published') AS viewed`,
  )
    .bind(grade, id, grade)
    .first<{ total: number; viewed: number }>();
  const overall = prog && prog.total > 0 ? Math.round((prog.viewed / prog.total) * 1000) / 10 : 0;

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

export default admin;
