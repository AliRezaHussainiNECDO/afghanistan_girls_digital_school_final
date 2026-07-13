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
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';

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
  const examRow = await c.env.DB.prepare('SELECT title FROM exams WHERE id = ?')
    .bind(examId)
    .first<{ title: string }>();
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

  return c.json({
    scorePercent: Math.round(score * 10) / 10,
    correctCount: correct,
    totalCount: total,
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

export default exams;
