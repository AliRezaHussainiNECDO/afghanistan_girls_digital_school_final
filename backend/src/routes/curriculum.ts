/**
 * routes/curriculum.ts — نصاب و پیشرفت (بخش ۶ و ۱۹.۲/۱۹.۳ سند).
 *
 * Endpointها (زیر `/api/v1`):
 *   GET  /grades
 *   GET  /subjects?grade=7
 *   GET  /subjects/:subjectId/chapters?grade=7
 *   GET  /chapters/:chapterId/lessons          (Bearer اختیاری → viewed)
 *   GET  /lessons/:lessonId                     (Bearer اختیاری → viewed)
 *   POST /lessons/:lessonId/view                (Bearer اجباری)
 *   GET  /students/:studentId/grade-map         (Bearer اجباری — Server-Authoritative)
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

const c11m = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en } };
}

async function userId(c: any): Promise<string | null> {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return (payload?.['sub'] as string | undefined) ?? null;
}

async function isAdmin(c: any): Promise<boolean> {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return payload?.['role'] === 'super_admin';
}

// ─────────────────────────────── Grades ───────────────────────────────────

c11m.get('/grades', async (c) => {
  const { results } = await c.env.DB.prepare(
    'SELECT number, name_fa FROM grades ORDER BY number',
  ).all();
  return c.json({ grades: results });
});

// ────────────────────────────── Subjects ──────────────────────────────────

c11m.get('/subjects', async (c) => {
  const grade = Number(c.req.query('grade') ?? '0');
  // ۱۰ مضمون ثابت + پرچم اینکه در این صنف محتوا دارند یا نه.
  const { results } = await c.env.DB.prepare(
    `SELECT s.id, s.name_fa, s.name_en, s.order_index,
       (SELECT COUNT(*) FROM chapters ch WHERE ch.subject_id = s.id AND ch.grade_number = ?
          AND ch.status = 'published') AS chapter_count
     FROM subjects s ORDER BY s.order_index`,
  )
    .bind(grade)
    .all();
  return c.json({ subjects: results });
});

// ────────────────────────────── Chapters ──────────────────────────────────

c11m.get('/subjects/:subjectId/chapters', async (c) => {
  const subjectId = c.req.param('subjectId');
  const grade = Number(c.req.query('grade') ?? '0');
  const { results } = await c.env.DB.prepare(
    `SELECT ch.id, ch.title_fa, ch.order_index,
       (SELECT COUNT(*) FROM lessons l WHERE l.chapter_id = ch.id AND l.status='published') AS lesson_count
     FROM chapters ch
     WHERE ch.subject_id = ? AND ch.grade_number = ? AND ch.status='published'
     ORDER BY ch.order_index`,
  )
    .bind(subjectId, grade)
    .all();
  return c.json({ chapters: results });
});

// ─────────────────────────────── Lessons ──────────────────────────────────

c11m.get('/chapters/:chapterId/lessons', async (c) => {
  const chapterId = c.req.param('chapterId');
  const uid = await userId(c);
  const { results } = await c.env.DB.prepare(
    `SELECT l.id, l.chapter_id, l.title_fa, l.estimated_minutes, l.order_index, l.content_body,
       CASE WHEN v.lesson_id IS NULL THEN 0 ELSE 1 END AS viewed
     FROM lessons l
     LEFT JOIN student_lesson_views v ON v.lesson_id = l.id AND v.user_id = ?
     WHERE l.chapter_id = ? AND l.status='published'
     ORDER BY l.order_index`,
  )
    .bind(uid ?? '', chapterId)
    .all();
  return c.json({ lessons: results });
});

c11m.get('/lessons/:lessonId', async (c) => {
  const lessonId = c.req.param('lessonId');
  const uid = await userId(c);
  const row = await c.env.DB.prepare(
    `SELECT l.id, l.chapter_id, l.title_fa, l.estimated_minutes, l.order_index, l.content_body,
       CASE WHEN v.lesson_id IS NULL THEN 0 ELSE 1 END AS viewed
     FROM lessons l
     LEFT JOIN student_lesson_views v ON v.lesson_id = l.id AND v.user_id = ?
     WHERE l.id = ? AND l.status='published'`,
  )
    .bind(uid ?? '', lessonId)
    .first();
  if (!row) return c.json(fail('NOT_FOUND', 'درس یافت نشد', 'Lesson not found'), 404);
  return c.json({ lesson: row });
});

// ثبت بازدید درس — ورودی منطق C1 (بخش ۶.۲). فقط دانش‌آموز واردشده.
c11m.post('/lessons/:lessonId/view', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const lessonId = c.req.param('lessonId');
  const exists = await c.env.DB.prepare("SELECT id FROM lessons WHERE id = ? AND status='published'")
    .bind(lessonId)
    .first();
  if (!exists) return c.json(fail('NOT_FOUND', 'درس یافت نشد', 'Lesson not found'), 404);
  await c.env.DB.prepare(
    'INSERT OR IGNORE INTO student_lesson_views (user_id, lesson_id) VALUES (?, ?)',
  )
    .bind(uid, lessonId)
    .run();
  return c.json({ success: true });
});

// ─────────────────────────────── Grade Map ────────────────────────────────
// Server-Authoritative (بخش ۶.۷): وضعیت هر مضمون از روی درس‌های دیده‌شده.

c11m.get('/students/:studentId/grade-map', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);

  // صنف فعلی از جدول users (پیش‌فرض ۷).
  const student = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?')
    .bind(uid)
    .first<{ current_grade: number | null }>();
  const grade = student?.current_grade ?? 7;

  // برای هر مضمون: مجموع درس‌های منتشرشده و تعداد دیده‌شده در این صنف.
  const { results } = await c.env.DB.prepare(
    `SELECT s.id AS subject_id, s.name_fa AS subject_name_fa,
       (SELECT COUNT(*) FROM lessons l
          JOIN chapters ch ON ch.id = l.chapter_id
          WHERE ch.subject_id = s.id AND ch.grade_number = ?
            AND l.status='published' AND ch.status='published') AS total_lessons,
       (SELECT COUNT(*) FROM lessons l
          JOIN chapters ch ON ch.id = l.chapter_id
          JOIN student_lesson_views v ON v.lesson_id = l.id AND v.user_id = ?
          WHERE ch.subject_id = s.id AND ch.grade_number = ?
            AND l.status='published' AND ch.status='published') AS viewed_lessons
     FROM subjects s ORDER BY s.order_index`,
  )
    .bind(grade, uid, grade)
    .all<{ subject_id: string; subject_name_fa: string; total_lessons: number; viewed_lessons: number }>();

  let sum = 0;
  const subjects = results.map((r) => {
    const completion = r.total_lessons > 0 ? (r.viewed_lessons / r.total_lessons) * 100 : 0;
    sum += completion;
    let status: string;
    if (r.total_lessons > 0 && r.viewed_lessons >= r.total_lessons) {
      status = 'completed';
    } else if (r.viewed_lessons > 0) {
      status = 'inProgress';
    } else {
      status = 'unlocked';
    }
    return {
      subjectId: r.subject_id,
      subjectNameFa: r.subject_name_fa,
      status,
      finalScore: null, // نمرات در ماژول ۲ (امتحانات) پر می‌شوند
      completionPercent: Math.round(completion * 10) / 10,
    };
  });

  return c.json({
    gradeNumber: grade,
    gradeLocked: false,
    gradeAveragePercent: subjects.length ? Math.round((sum / subjects.length) * 10) / 10 : 0,
    attendanceRatePercent: 0, // در ماژول ۳ (حاضری) پر می‌شود
    subjects,
  });
});

// ───────────── خلاصهٔ داشبورد خانهٔ شاگرد (بخش ۵.۵/۶/۷/۱۲) ─────────────
c11m.get('/students/me/dashboard-summary', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const u = await c.env.DB.prepare('SELECT first_name, current_grade FROM users WHERE id = ?')
    .bind(uid)
    .first<{ first_name: string; current_grade: number | null }>();
  const grade = u?.current_grade ?? 7;

  // پیشرفت هر مضمون + یافتن اولین درس دیده‌نشده (درس فعلی).
  const { results: subs } = await c.env.DB.prepare(
    `SELECT s.id, s.name_fa,
       (SELECT COUNT(*) FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
          WHERE ch.subject_id=s.id AND ch.grade_number=? AND l.status='published' AND ch.status='published') AS total,
       (SELECT COUNT(*) FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
          JOIN student_lesson_views v ON v.lesson_id=l.id AND v.user_id=?
          WHERE ch.subject_id=s.id AND ch.grade_number=? AND l.status='published' AND ch.status='published') AS viewed
     FROM subjects s ORDER BY s.order_index`,
  )
    .bind(grade, uid, grade)
    .all<{ id: string; name_fa: string; total: number; viewed: number }>();

  let sum = 0;
  const recommended: string[] = [];
  for (const r of subs) {
    const comp = r.total > 0 ? (r.viewed / r.total) * 100 : 0;
    sum += comp;
    if (r.viewed > 0 && r.viewed < r.total && recommended.length < 2) recommended.push(r.name_fa);
  }
  const overall = subs.length ? Math.round((sum / subs.length) * 10) / 10 : 0;

  // درس فعلی: اولین درس منتشرشدهٔ دیده‌نشده در این صنف.
  const nextLesson = await c.env.DB.prepare(
    `SELECT l.title_fa, s.name_fa AS subject_name FROM lessons l
       JOIN chapters ch ON ch.id=l.chapter_id
       JOIN subjects s ON s.id=ch.subject_id
     WHERE ch.grade_number=? AND l.status='published' AND ch.status='published'
       AND l.id NOT IN (SELECT lesson_id FROM student_lesson_views WHERE user_id=?)
     ORDER BY s.order_index, ch.order_index, l.order_index LIMIT 1`,
  )
    .bind(grade, uid)
    .first<{ title_fa: string; subject_name: string }>();

  // امتحان پیش رو (عنوان) و سمینار پیش رو (عنوان + تاریخ).
  const exam = await c.env.DB.prepare(
    "SELECT title FROM exams WHERE grade_number=? AND status='published' ORDER BY created_at DESC LIMIT 1",
  )
    .bind(grade)
    .first<{ title: string }>();
  const seminar = await c.env.DB.prepare(
    "SELECT title, scheduled_start FROM seminars WHERE audience='students' AND status IN ('published','registrationClosed','live') ORDER BY scheduled_start LIMIT 1",
  ).first<{ title: string; scheduled_start: string }>();

  return c.json({
    studentDisplayName: u?.first_name ?? '',
    overallProgressPercent: overall,
    currentLessonTitle: nextLesson?.title_fa ?? 'درسی برای شروع موجود نیست',
    currentSubjectNameFa: nextLesson?.subject_name ?? '',
    upcomingExamTitle: exam?.title ?? null,
    upcomingExamDate: null,
    upcomingSeminarTitle: seminar?.title ?? null,
    upcomingSeminarDate: seminar?.scheduled_start ?? null,
    recommendedTopics: recommended,
  });
});

// ═══════════════════ کتابخانهٔ نصاب (پایگاه دانش معلم هوشمند) ═════════════════
// متن استخراج‌شدهٔ کتاب‌های درسی، روی سرور تا بین همهٔ کاربران و معلم هوشمند
// مشترک باشد (به‌جای ذخیرهٔ محلی هر دستگاه).

function libraryBookJson(r: any) {
  return {
    id: r.id,
    subjectId: r.subject_id,
    title: r.title,
    uploadedAt: r.uploaded_at,
    pageCount: r.page_count,
    gradeId: r.grade_id,
    extractedText: r.extracted_text ?? '',
  };
}

c11m.get('/curriculum-library/books', async (c) => {
  if (!(await userId(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM curriculum_library_books ORDER BY uploaded_at DESC',
  ).all<any>();
  return c.json({ books: results.map(libraryBookJson) });
});

c11m.get('/curriculum-library/subjects/:subjectId/books', async (c) => {
  if (!(await userId(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM curriculum_library_books WHERE subject_id = ? ORDER BY uploaded_at DESC',
  )
    .bind(c.req.param('subjectId'))
    .all<any>();
  return c.json({ books: results.map(libraryBookJson) });
});

c11m.post('/curriculum-library/books', async (c) => {
  if (!(await isAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const b = await c.req
    .json<{ subjectId?: string; title?: string; pageCount?: number; gradeId?: number; extractedText?: string }>()
    .catch(() => null);
  const subjectId = String(b?.subjectId ?? '').trim();
  const title = String(b?.title ?? '').trim();
  if (!subjectId || !title) {
    return c.json(fail('BAD_REQUEST', 'مضمون و عنوان لازم است', 'Missing fields'), 400);
  }
  const gradeId = Number(b?.gradeId ?? 0);
  // حداکثر ۴۰۰ هزار نویسه (هماهنگ با محدودیت کلاینت).
  const text = String(b?.extractedText ?? '').slice(0, 400000);
  const id = `book_${Date.now()}`;
  // هر صنف فقط یک کتاب رسمی برای هر مضمون دارد → جایگزینی.
  if (gradeId !== 0) {
    await c.env.DB.prepare('DELETE FROM curriculum_library_books WHERE subject_id = ? AND grade_id = ?')
      .bind(subjectId, gradeId)
      .run();
  }
  await c.env.DB.prepare(
    'INSERT INTO curriculum_library_books (id, subject_id, title, page_count, grade_id, extracted_text) VALUES (?, ?, ?, ?, ?, ?)',
  )
    .bind(id, subjectId, title, Number(b?.pageCount ?? 0), gradeId, text)
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM curriculum_library_books WHERE id = ?').bind(id).first<any>();
  return c.json({ book: libraryBookJson(row) }, 201);
});

c11m.delete('/curriculum-library/books/:id', async (c) => {
  if (!(await isAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  await c.env.DB.prepare('DELETE FROM curriculum_library_books WHERE id = ?').bind(c.req.param('id')).run();
  return c.json({ success: true });
});

export default c11m;
