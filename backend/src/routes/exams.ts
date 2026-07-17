/**
 * routes/exams.ts — امتحانات، نمره‌دهی و گواهی‌نامه (بخش ۷/۸ سند).
 *
 * Endpointها (زیر `/api/v1`):
 *   GET  /exams/available                 لیست امتحانات منتشرشده (صنف کاربر)
 *   GET  /exams/:examId/questions         سؤالات بدون پاسخ صحیح (بخش ۷.۲)
 *   POST /exams/:examId/submit            نمره‌دهی سمت سرور + ثبت تلاش
 *   GET  /students/:studentId/certificates
 *   POST /admin/certificates              صدور گواهی‌نامه (مدیر)
 *   DELETE /admin/certificates/:id        ابطال گواهی‌نامه (مدیر)
 *
 *   -- مدیریت امتحانات/سؤالات (فقط مدیر — رفع اشکال: قبلاً هیچ راهی برای
 *      ساخت امتحان/سؤال از داخل برنامه وجود نداشت، پس امتحان «نهایی» برای
 *      هیچ صنفی هرگز وجود نداشت و سیستم ارتقا عملاً غیرقابل‌دسترس بود) --
 *   GET    /admin/exams                       لیست همهٔ امتحانات (همهٔ وضعیت‌ها)
 *   POST   /admin/exams                       ایجاد/ویرایش امتحان
 *   PATCH  /admin/exams/:id/status             تغییر وضعیت (draft/published/closed)
 *   DELETE /admin/exams/:id                    حذف امتحان + سؤالات/تلاش‌های وابسته
 *   GET    /admin/exams/:examId/questions      سؤالات با پاسخ صحیح (فقط مدیر)
 *   POST   /admin/exams/:examId/questions      ایجاد/ویرایش سؤال
 *   DELETE /admin/questions/:id                حذف سؤال
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { promoteIfEligible } from '../lib/progress';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

const exams = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en } };
}

async function auth(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

const TYPE_MAP: Record<string, string> = {
  daily_quiz: 'dailyQuiz',
  homework: 'homework',
  monthly: 'monthly',
  final: 'finalExam',
};

// ────────────────────────── لیست امتحانات موجود ─────────────────────────────

exams.get('/exams/available', async (c) => {
  const me = await auth(c);
  // اگر توکن باشد، فقط امتحانات صنف کاربر؛ در غیر این صورت همه (برای تست).
  let grade = 0;
  if (me) {
    const u = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?')
      .bind(me.sub)
      .first<{ current_grade: number | null }>();
    grade = u?.current_grade ?? 0;
  }
  const query = grade
    ? c.env.DB.prepare(
        `SELECT e.id, e.type, e.duration_minutes, e.grade_number, s.name_fa AS subject_name_fa,
           (SELECT COUNT(*) FROM questions q WHERE q.exam_id = e.id) AS question_count
         FROM exams e JOIN subjects s ON s.id = e.subject_id
         WHERE e.status='published' AND e.grade_number = ? ORDER BY e.created_at DESC`,
      ).bind(grade)
    : c.env.DB.prepare(
        `SELECT e.id, e.type, e.duration_minutes, e.grade_number, s.name_fa AS subject_name_fa,
           (SELECT COUNT(*) FROM questions q WHERE q.exam_id = e.id) AS question_count
         FROM exams e JOIN subjects s ON s.id = e.subject_id
         WHERE e.status='published' ORDER BY e.created_at DESC`,
      );
  const { results } = await query.all<any>();
  const list = results.map((e) => ({
    id: e.id,
    subjectNameFa: e.subject_name_fa,
    type: TYPE_MAP[e.type as string] ?? 'dailyQuiz',
    durationMinutes: e.duration_minutes,
    questionCount: e.question_count,
  }));
  return c.json({ exams: list });
});

// ─────────────────────────── سؤالات (بدون پاسخ) ─────────────────────────────

exams.get('/exams/:examId/questions', async (c) => {
  const examId = c.req.param('examId');
  const { results } = await c.env.DB.prepare(
    'SELECT id, text, options FROM questions WHERE exam_id = ? ORDER BY order_index',
  )
    .bind(examId)
    .all<{ id: string; text: string; options: string }>();
  const list = results.map((q) => ({
    id: q.id,
    text: q.text,
    options: JSON.parse(q.options),
    // correctIndex عمداً فرستاده نمی‌شود (بخش ۷.۲ — نمره‌دهی فقط سمت سرور).
  }));
  return c.json({ questions: list });
});

// ─────────────────────── ارسال پاسخ‌ها + نمره‌دهی سرور ───────────────────────

exams.post('/exams/:examId/submit', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const examId = c.req.param('examId');
  const body = await c.req.json<{ answers?: Record<string, number> }>().catch(() => null);
  const answers = body?.answers ?? {};

  const { results } = await c.env.DB.prepare(
    'SELECT id, correct_index FROM questions WHERE exam_id = ?',
  )
    .bind(examId)
    .all<{ id: string; correct_index: number }>();
  if (results.length === 0) {
    return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found'), 404);
  }

  let correct = 0;
  for (const q of results) {
    if (answers[q.id] === q.correct_index) correct++;
  }
  const total = results.length;
  const score = total === 0 ? 0 : (correct / total) * 100;

  const roundedScore = Math.round(score * 10) / 10;
  // ثبت تلاش + یک اعلان نتیجه (تا اعلان‌ها از رویداد واقعی پر شوند — بخش ۱۳.۱).
  const examRow = await c.env.DB.prepare('SELECT title, type, grade_number FROM exams WHERE id = ?')
    .bind(examId)
    .first<{ title: string; type: string; grade_number: number }>();
  await c.env.DB.batch([
    c.env.DB.prepare(
      'INSERT INTO exam_attempts (id, exam_id, user_id, score_percent, correct_count, total_count) VALUES (?, ?, ?, ?, ?, ?)',
    ).bind(uid(), examId, me.sub, score, correct, total),
    c.env.DB.prepare(
      "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind) VALUES (?, ?, ?, ?, 'medium', 'exam')",
    ).bind(
      uid(),
      me.sub,
      'نتیجهٔ امتحان',
      `نمرهٔ شما در «${examRow?.title ?? 'امتحان'}»: ${roundedScore}٪ (${correct} از ${total})`,
    ),
  ]);

  // رفع اشکال ارتقای صنف: قبلاً ارتقا فقط در ذخیرهٔ محلی گوشی شبیه‌سازی
  // می‌شد. اکنون اگر این یک امتحانِ «نهایی» بود، بلافاصله شرایط ارتقای
  // واقعی (تکمیل تمام مضامین + کامیابی در امتحان) روی سرور بررسی می‌شود.
  let promotion: { promoted: boolean; newGrade: number | null } = { promoted: false, newGrade: null };
  if (examRow?.type === 'final') {
    promotion = await promoteIfEligible(c.env.DB, me.sub);
  }

  return c.json({
    scorePercent: Math.round(score * 10) / 10,
    correctCount: correct,
    totalCount: total,
    promoted: promotion.promoted,
    newGrade: promotion.newGrade,
  });
});

// ──────────────────────────── گواهی‌نامه‌ها ──────────────────────────────────

exams.get('/students/:studentId/certificates', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  // شاگرد فقط گواهی خودش؛ مدیر همه (بخش ۱۳ب.۳/۱۵.۲).
  const target = me.role === 'super_admin' ? c.req.param('studentId') : me.sub;
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM certificates WHERE student_id = ? ORDER BY issued_at DESC',
  )
    .bind(target)
    .all<any>();
  return c.json({ certificates: results.map(certJson) });
});

exams.post('/admin/certificates', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const b = await c.req.json<any>().catch(() => null);
  if (!b?.studentId) return c.json(fail('BAD_REQUEST', 'ورودی ناقص', 'Missing fields'), 400);
  const id = uid();
  const grade = Number(b.grade ?? 7);
  const serial = `AGDS-${grade}-${Date.now()}`;
  await c.env.DB.prepare(
    `INSERT INTO certificates (id, serial, student_id, student_name, grade, year_label, average, honor, issued_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      id,
      serial,
      String(b.studentId),
      String(b.studentName ?? ''),
      grade,
      String(b.yearLabel ?? ''),
      Number(b.average ?? 0),
      String(b.honor ?? ''),
      'مدیریت مکتب',
    )
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM certificates WHERE id = ?').bind(id).first<any>();
  return c.json({ certificate: certJson(row) }, 201);
});

exams.delete('/admin/certificates/:id', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  await c.env.DB.prepare('DELETE FROM certificates WHERE id = ?').bind(c.req.param('id')).run();
  return c.json({ success: true });
});

function certJson(r: any) {
  return {
    id: r.id,
    serial: r.serial,
    studentId: r.student_id,
    studentName: r.student_name,
    grade: r.grade,
    yearLabel: r.year_label,
    average: r.average,
    honor: r.honor,
    issuedAt: r.issued_at,
    issuedBy: r.issued_by,
  };
}

// ═══════════ مدیریت امتحانات و سؤالات (فقط مدیر — احراز صنف نهایی) ═══════════
// قبلاً هیچ Endpointای برای ساخت/ویرایش امتحان یا سؤال وجود نداشت — تنها
// دادهٔ موجود، دو امتحانِ نمونهٔ Seed در migration 0004 برای صنف ۷ بود و
// هیچ امتحان نوع «نهایی» (final) برای هیچ صنفی وجود نداشت. این یعنی
// `promoteIfEligible` (بخش ۷.۴/lib/progress.ts) عملاً هرگز از مسیر امتحان
// واقعی قابل بررسی نبود. این بخش به مدیر اجازه می‌دهد امتحان و سؤالات آن
// را مستقیماً از داخل برنامه بسازد/ویرایش/حذف کند.

const EXAM_TYPES = new Set(['daily_quiz', 'homework', 'monthly', 'final']);
const EXAM_STATUSES = new Set(['draft', 'published', 'closed']);

function adminExamJson(r: any) {
  return {
    id: r.id,
    subjectId: r.subject_id,
    subjectNameFa: r.subject_name_fa,
    gradeNumber: r.grade_number,
    type: r.type,
    title: r.title,
    durationMinutes: r.duration_minutes,
    status: r.status,
    questionCount: r.question_count ?? 0,
    createdAt: r.created_at,
  };
}

const ADMIN_EXAM_SELECT = `
  SELECT e.*, s.name_fa AS subject_name_fa,
    (SELECT COUNT(*) FROM questions q WHERE q.exam_id = e.id) AS question_count
  FROM exams e JOIN subjects s ON s.id = e.subject_id`;

exams.get('/admin/exams', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const { results } = await c.env.DB.prepare(`${ADMIN_EXAM_SELECT} ORDER BY e.grade_number, e.created_at DESC`).all<any>();
  return c.json({ exams: results.map(adminExamJson) });
});

exams.post('/admin/exams', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const b = await c.req
    .json<{
      id?: string;
      subjectId?: string;
      gradeNumber?: number;
      type?: string;
      title?: string;
      durationMinutes?: number;
      status?: string;
    }>()
    .catch(() => null);
  const subjectId = String(b?.subjectId ?? '').trim();
  const gradeNumber = Number(b?.gradeNumber ?? 0);
  const title = String(b?.title ?? '').trim();
  const type = EXAM_TYPES.has(String(b?.type)) ? String(b!.type) : 'daily_quiz';
  const status = EXAM_STATUSES.has(String(b?.status)) ? String(b!.status) : 'draft';
  const durationMinutes = Number(b?.durationMinutes ?? 10);
  if (!subjectId || !gradeNumber || !title) {
    return c.json(fail('BAD_REQUEST', 'مضمون، صنف و عنوان لازم است', 'Missing fields'), 400);
  }

  const id = b?.id && String(b.id).trim().length > 0 ? String(b.id).trim() : uid();
  const existing = await c.env.DB.prepare('SELECT id FROM exams WHERE id = ?').bind(id).first();
  if (existing) {
    await c.env.DB.prepare(
      'UPDATE exams SET subject_id=?, grade_number=?, type=?, title=?, duration_minutes=?, status=? WHERE id=?',
    )
      .bind(subjectId, gradeNumber, type, title, durationMinutes, status, id)
      .run();
    const row = await c.env.DB.prepare(`${ADMIN_EXAM_SELECT} WHERE e.id = ?`).bind(id).first<any>();
    return c.json({ exam: adminExamJson(row) }, 200);
  }
  await c.env.DB.prepare(
    `INSERT INTO exams (id, subject_id, grade_number, type, title, duration_minutes, status)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(id, subjectId, gradeNumber, type, title, durationMinutes, status)
    .run();
  const row = await c.env.DB.prepare(`${ADMIN_EXAM_SELECT} WHERE e.id = ?`).bind(id).first<any>();
  return c.json({ exam: adminExamJson(row) }, 201);
});

exams.patch('/admin/exams/:id/status', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  const status = EXAM_STATUSES.has(String(b?.status)) ? String(b!.status) : 'draft';
  await c.env.DB.prepare('UPDATE exams SET status = ? WHERE id = ?').bind(status, c.req.param('id')).run();
  return c.json({ success: true });
});

exams.delete('/admin/exams/:id', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const examId = c.req.param('id');
  await c.env.DB.prepare('DELETE FROM exam_attempts WHERE exam_id = ?').bind(examId).run();
  await c.env.DB.prepare('DELETE FROM questions WHERE exam_id = ?').bind(examId).run();
  await c.env.DB.prepare('DELETE FROM exams WHERE id = ?').bind(examId).run();
  return c.json({ success: true });
});

// سؤالات — نسخهٔ مدیر شامل پاسخ صحیح (برخلاف /exams/:examId/questions عمومی).

exams.get('/admin/exams/:examId/questions', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const { results } = await c.env.DB.prepare(
    'SELECT id, exam_id, text, options, correct_index, order_index FROM questions WHERE exam_id = ? ORDER BY order_index',
  )
    .bind(c.req.param('examId'))
    .all<any>();
  const list = results.map((q) => ({
    id: q.id,
    examId: q.exam_id,
    text: q.text,
    options: JSON.parse(q.options),
    correctIndex: q.correct_index,
    orderIndex: q.order_index,
  }));
  return c.json({ questions: list });
});

exams.post('/admin/exams/:examId/questions', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const examId = c.req.param('examId');
  const examExists = await c.env.DB.prepare('SELECT id FROM exams WHERE id = ?').bind(examId).first();
  if (!examExists) return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found'), 404);

  const b = await c.req
    .json<{
      id?: string;
      text?: string;
      options?: string[];
      correctIndex?: number;
      orderIndex?: number;
    }>()
    .catch(() => null);
  const text = String(b?.text ?? '').trim();
  const options = Array.isArray(b?.options) ? b!.options!.map((o) => String(o)) : [];
  const correctIndex = Number(b?.correctIndex ?? -1);
  if (!text || options.length < 2 || correctIndex < 0 || correctIndex >= options.length) {
    return c.json(
      fail('BAD_REQUEST', 'متن سؤال، حداقل ۲ گزینه و پاسخ صحیح معتبر لازم است', 'Missing/invalid fields'),
      400,
    );
  }

  const id = b?.id && String(b.id).trim().length > 0 ? String(b.id).trim() : uid();
  const existing = await c.env.DB.prepare('SELECT id FROM questions WHERE id = ?').bind(id).first();
  let orderIndex = Number(b?.orderIndex ?? 0);
  if (!existing && !orderIndex) {
    const countRow = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM questions WHERE exam_id = ?')
      .bind(examId)
      .first<{ n: number }>();
    orderIndex = (countRow?.n ?? 0) + 1;
  }
  if (existing) {
    await c.env.DB.prepare(
      'UPDATE questions SET text=?, options=?, correct_index=?, order_index=? WHERE id=?',
    )
      .bind(text, JSON.stringify(options), correctIndex, orderIndex, id)
      .run();
    return c.json({ question: { id, examId, text, options, correctIndex, orderIndex } }, 200);
  }
  await c.env.DB.prepare(
    'INSERT INTO questions (id, exam_id, text, options, correct_index, order_index) VALUES (?, ?, ?, ?, ?, ?)',
  )
    .bind(id, examId, text, JSON.stringify(options), correctIndex, orderIndex)
    .run();
  return c.json({ question: { id, examId, text, options, correctIndex, orderIndex } }, 201);
});

exams.delete('/admin/questions/:id', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  await c.env.DB.prepare('DELETE FROM questions WHERE id = ?').bind(c.req.param('id')).run();
  return c.json({ success: true });
});

export default exams;
