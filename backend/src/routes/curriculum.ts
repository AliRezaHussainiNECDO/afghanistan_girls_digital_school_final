/**
 * routes/curriculum.ts — نصاب و پیشرفت (بخش ۶ و ۱۹.۲/۱۹.۳ سند).
 *
 * Endpointها (زیر `/api/v1`):
 *   GET  /grades
 *   GET  /subjects?grade=7
 *   GET  /subjects/:subjectId/chapters?grade=7   (Bearer اختیاری → قفل/پیشرفت هر فصل)
 *   GET  /chapters/:chapterId/lessons          (Bearer اختیاری → viewed)
 *   GET  /lessons/:lessonId                     (Bearer اختیاری → viewed)
 *   POST /lessons/:lessonId/view                (Bearer اجباری — امتیاز فعالیت هم می‌دهد)
 *   GET  /students/:studentId/grade-map         (Bearer اجباری — Server-Authoritative)
 *   GET  /students/me/points                    (Bearer اجباری) خلاصهٔ امتیاز شاگرد
 *   GET  /students/:studentId/points            (Bearer اجباری — خودش/مدیر/والدِ لینک‌شده)
 *
 *   GET    /admin/curriculum/lessons                    (فقط مدیر — رفع اشکال تب «دروس» CMS)
 *   POST   /admin/curriculum/lessons                    (فقط مدیر — ایجاد/ویرایش، فصل را خودکار پیدا/می‌سازد)
 *   PATCH  /admin/curriculum/lessons/:id/status         (فقط مدیر)
 *   DELETE /admin/curriculum/lessons/:id                (فقط مدیر)
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import {
  getSubjectProgressList,
  averagePercent,
  getChapterList,
  getPointsSummary,
  recordLessonView,
  getPromotionStatus,
} from '../lib/progress';
import { autoAssignLessonHomework } from '../lib/lessonHomework';
import { logAudit, clientIp } from '../lib/audit';

type Bindings = { DB: D1Database; JWT_SECRET: string; GEMINI_API_KEY?: string; GEMINI_VISION_MODEL?: string; };
const c11m = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}
async function userId(c: any): Promise<string | null> {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return (payload?.['sub'] as string | undefined) ?? null;
}
async function isAdmin(c: any): Promise<boolean> {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return payload?.['role'] === 'super_admin';
}
/** شناسهٔ مدیر جاری — برای audit_logs (بخش ۲۰.۳). null یعنی مجاز نیست. */
async function adminId(c: any): Promise<string | null> {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return payload?.['role'] === 'super_admin' ? ((payload['sub'] as string) ?? null) : null;
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
// شناسایی هوشمند عناوین فصل (سمت کلاینت هنگام آپلود کتاب) + قفل‌گذاری ترتیبی:
// فصل اول همیشه باز است؛ فصل بعدی فقط بعد از تکمیل فصل جاری باز می‌شود.

c11m.get('/subjects/:subjectId/chapters', async (c) => {
  const subjectId = c.req.param('subjectId');
  const grade = Number(c.req.query('grade') ?? '0');
  const uid = await userId(c); // اختیاری — بدون ورود، فقط فصل اول باز نمایش داده می‌شود.
  const chapters = await getChapterList(c.env.DB, subjectId, grade, uid);
  return c.json({
    chapters: chapters.map((ch) => ({
      id: ch.id,
      title_fa: ch.titleFa,
      order_index: ch.orderIndex,
      lesson_count: ch.lessonCount,
      viewed_count: ch.viewedCount,
      progress_percent: ch.percent,
      completed: ch.completed,
      unlocked: ch.unlocked,
      source_book_id: ch.sourceBookId,
    })),
  });
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
  if (!row) return c.json(fail('NOT_FOUND', 'درس یافت نشد', 'Lesson not found', 'درس ونه موندل شو', 'Leçon introuvable'), 404);
  return c.json({ lesson: row });
});

// ثبت بازدید درس — ورودی منطق C1 (بخش ۶.۲) + اهدای امتیاز فعالیت (Gamification)
// + بررسی خودکار تکمیل فصل (پایهٔ قفل‌گشایی فصل بعدی). فقط دانش‌آموز واردشده.
c11m.post('/lessons/:lessonId/view', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const lessonId = c.req.param('lessonId');
  const result = await recordLessonView(c.env.DB, uid, lessonId);
  if (!result.found) return c.json(fail('NOT_FOUND', 'درس یافت نشد', 'Lesson not found', 'درس ونه موندل شو', 'Leçon introuvable'), 404);

  // رفع اشکال (طبق درخواست کاربر): قبلاً با همین بازدیدِ اول، کار خانگی
  // خودکار ساخته و ارسال می‌شد — یعنی شاگرد هنوز درس را نخوانده، کار خانگی
  // می‌گرفت. حالا کار خانگی فقط وقتی ساخته می‌شود که شاگرد خودش در صفحهٔ
  // گفتگوی درس دکمهٔ «این درس را یاد گرفتم» را بزند
  // (`POST /lessons/:lessonId/learned` — پایین همین فایل).

  return c.json({
    success: true,
    pointsAwarded: result.firstView ? 10 : 0,
    chapterJustCompleted: result.chapterJustCompleted,
    chapterBonusAwarded: result.chapterJustCompleted ? 25 : 0,
  });
});

// «این درس را یاد گرفتم» — تنها نقطهٔ ساخت کار خانگی (طبق درخواست کاربر):
// شاگرد بعد از خواندن درس، خودش این دکمه را در صفحهٔ گفتگوی همان درس می‌زند.
// منطق: برای هر (شاگرد، درس) فقط **یک** کار خانگی ساخته می‌شود — اگر شاگرد
// همان درس را دوباره بخواند و دوباره دکمه را بزند، کار خانگی تازه داده
// نمی‌شود (idempotent — بررسی داخل lib/lessonHomework.ts). فقط وقتی به
// درس‌های بعدی/جدید پیش برود، برای آن درس‌های تازه کار خانگی جدید می‌گیرد.
c11m.post('/lessons/:lessonId/learned', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const lessonId = c.req.param('lessonId');

  // «یاد گرفتم» یعنی درس دیده شده — اگر بازدید هنوز ثبت نشده بود (مثلاً
  // مستقیم از گفتگو)، همین‌جا ثبت می‌شود تا پیشرفت/امتیاز همه‌جا هماهنگ بماند.
  const view = await recordLessonView(c.env.DB, uid, lessonId);
  if (!view.found) return c.json(fail('NOT_FOUND', 'درس یافت نشد', 'Lesson not found', 'درس ونه موندل شو', 'Leçon introuvable'), 404);

  const lessonRow = await c.env.DB.prepare(
    `SELECT l.title_fa, l.content_body, ch.id AS chapter_id, ch.subject_id, ch.grade_number, s.name_fa AS subject_name_fa
       FROM lessons l
       JOIN chapters ch ON ch.id = l.chapter_id
       LEFT JOIN subjects s ON s.id = ch.subject_id
      WHERE l.id = ?`,
  )
    .bind(lessonId)
    .first<{
      title_fa: string;
      content_body: string;
      chapter_id: string;
      subject_id: string;
      grade_number: number;
      subject_name_fa: string | null;
    }>();
  if (!lessonRow) return c.json(fail('NOT_FOUND', 'درس یافت نشد', 'Lesson not found', 'درس ونه موندل شو', 'Leçon introuvable'), 404);

  // ساخت کار خانگی — این بار await می‌شود (نه waitUntil) تا کلاینت بداند
  // نتیجه چه شد و پیام درست («ساخته شد» یا «قبلاً داده شده») نشان دهد.
  const outcome = await autoAssignLessonHomework(c.env, {
    studentId: uid,
    lessonId,
    chapterId: lessonRow.chapter_id,
    subjectId: lessonRow.subject_id,
    subjectNameFa: lessonRow.subject_name_fa ?? '',
    classLevel: lessonRow.grade_number,
    lessonTitleFa: lessonRow.title_fa,
    lessonContentBody: lessonRow.content_body,
  });

  return c.json({
    success: true,
    // 'created' | 'exists' | 'failed' | 'not_configured'
    homework: outcome,
    assigned: outcome === 'created',
    alreadyAssigned: outcome === 'exists',
  });
});

// ─────────────────────────────── Grade Map ────────────────────────────────
// Server-Authoritative (بخش ۶.۷): وضعیت هر مضمون از روی درس‌های دیده‌شده.
// از lib/progress.ts استفاده می‌کند تا عدد پیشرفت با سایر داشبوردها یکسان باشد.

c11m.get('/students/:studentId/grade-map', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);

  // صنف فعلی از جدول users (پیش‌فرض ۷).
  const student = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?')
    .bind(uid)
    .first<{ current_grade: number | null }>();
  const activeGrade = student?.current_grade ?? 7;

  // رفع اشکال: قبلاً این Endpoint همیشه فقط «صنف فعال» را برمی‌گرداند —
  // حتی وقتی شاگرد از نوار انتخاب صنف یکی از صنوف پایین‌ترِ تکمیل‌شده‌اش را
  // برای مرور باز می‌کرد. یعنی «وضعیت ارتقا» و «درصد هر مضمون» در تمام
  // صنف‌های مرورشده عیناً یک چیز (وضعیت صنف فعال) را نشان می‌دادند. اکنون
  // کوئری اختیاری `?grade=` هر صنفِ مجاز (۷ الی صنف فعال) را می‌پذیرد؛
  // درخواست صنف قفل‌شده (بالاتر از صنف فعال) نادیده گرفته و به صنف فعال
  // برمی‌گردد.
  const requestedGrade = Number(c.req.query('grade') ?? '0');
  const grade = requestedGrade >= 7 && requestedGrade <= activeGrade ? requestedGrade : activeGrade;

  const subjectsProgress = await getSubjectProgressList(c.env.DB, uid, grade);
  const subjects = subjectsProgress.map((r) => ({
    subjectId: r.subjectId,
    subjectNameFa: r.nameFa,
    status: r.status === 'completed' ? 'completed' : r.status === 'inProgress' ? 'inProgress' : 'unlocked',
    finalScore: null, // نمرات در ماژول ۲ (امتحانات) پر می‌شوند
    completionPercent: r.percent,
  }));

  // وضعیت واقعی ارتقا (رفع اشکال: قبلاً این عدد فقط محلی/ساختگی بود —
  // بخش lib/progress.ts::getPromotionStatus). برای صنف‌های پایین‌تر از صنف
  // فعال، این عملاً کارنامهٔ تاریخیِ همان صنف را نشان می‌دهد (چون شاگرد از
  // آن صنف واقعاً ارتقا گرفته، این مقادیر تکمیل‌شده خواهند بود).
  const promotion = await getPromotionStatus(c.env.DB, uid, grade);

  return c.json({
    gradeNumber: grade,
    activeGradeNumber: activeGrade,
    gradeLocked: false,
    gradeAveragePercent: averagePercent(subjectsProgress),
    attendanceRatePercent: 0, // در ماژول ۳ (حاضری) پر می‌شود
    subjects,
    allSubjectsComplete: promotion.allSubjectsComplete,
    examPassed: promotion.examPassed,
    examBestScore: promotion.examBestScore,
    canPromote: promotion.canPromote,
  });
});

// ───────────── خلاصهٔ داشبورد خانهٔ شاگرد (بخش ۵.۵/۶/۷/۱۲) ─────────────

// «ادامهٔ یادگیری» — به‌جای فقط یک درس/مضمون ثابت (که قبلاً همیشه اولین
// مضمونِ برنامهٔ درسی را نشان می‌داد)، اینجا تا ۳ مضمونی که شاگرد واقعاً در
// آن‌ها فعالیت کرده (viewed > 0) و هنوز تکمیل نشده را برمی‌گردانیم، به
// ترتیب «آخرین بار که در آن درس دیده»، تا شاگرد دقیقاً از همان‌جایی که رها
// کرده ادامه دهد. اگر شاگرد هنوز هیچ درسی ندیده (روز اول)، اولین درسِ
// برنامهٔ درسی به‌عنوان نقطهٔ شروع پیشنهاد می‌شود.
async function buildContinueLearning(
  db: D1Database,
  studentId: string,
  grade: number,
  subjectsProgress: Awaited<ReturnType<typeof getSubjectProgressList>>,
): Promise<{ subjectId: string; subjectNameFa: string; lessonTitle: string; progressPercent: number }[]> {
  const inProgressIds = new Set(subjectsProgress.filter((s) => s.status === 'inProgress').map((s) => s.subjectId));

  const { results: recency } = await db
    .prepare(
      `SELECT ch.subject_id AS subject_id, MAX(v.viewed_at) AS last_viewed
         FROM student_lesson_views v
         JOIN lessons l ON l.id = v.lesson_id
         JOIN chapters ch ON ch.id = l.chapter_id
        WHERE v.user_id = ? AND ch.grade_number = ?
        GROUP BY ch.subject_id
        ORDER BY last_viewed DESC`,
    )
    .bind(studentId, grade)
    .all<{ subject_id: string; last_viewed: string }>();

  const orderedSubjectIds = recency.map((r) => r.subject_id).filter((id) => inProgressIds.has(id)).slice(0, 3);

  // اگر هیچ مضمونی «در حال انجام» نیست (روز اول شاگرد)، اولین مضمون با محتوا
  // در این صنف را به‌عنوان نقطهٔ شروع پیشنهاد بده.
  if (orderedSubjectIds.length === 0) {
    const first = subjectsProgress.find((s) => s.totalLessons > 0);
    if (first) orderedSubjectIds.push(first.subjectId);
  }

  const items: { subjectId: string; subjectNameFa: string; lessonTitle: string; progressPercent: number }[] = [];
  for (const subjectId of orderedSubjectIds) {
    const sp = subjectsProgress.find((s) => s.subjectId === subjectId);
    if (!sp) continue;
    const lesson = await db
      .prepare(
        `SELECT l.title_fa FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
          WHERE ch.subject_id=? AND ch.grade_number=? AND l.status='published' AND ch.status='published'
            AND l.id NOT IN (SELECT lesson_id FROM student_lesson_views WHERE user_id=?)
          ORDER BY ch.order_index, l.order_index LIMIT 1`,
      )
      .bind(subjectId, grade, studentId)
      .first<{ title_fa: string }>();
    // اگر درس دیده‌نشده‌ای باقی نمانده (مثلاً همهٔ درس‌ها دیده شده ولی نمرهٔ
    // نهایی هنوز کامل نشده)، این مضمون را رد کن — چیزی برای «ادامه» ندارد.
    if (!lesson) continue;
    items.push({
      subjectId,
      subjectNameFa: sp.nameFa,
      lessonTitle: lesson.title_fa,
      progressPercent: sp.percent,
    });
  }
  return items;
}

c11m.get('/students/me/dashboard-summary', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const u = await c.env.DB.prepare('SELECT first_name, current_grade FROM users WHERE id = ?')
    .bind(uid)
    .first<{ first_name: string; current_grade: number | null }>();
  const grade = u?.current_grade ?? 7;

  // پیشرفت هر مضمون (منبع واحد) — برای پیدا کردن مضامین «در حال انجام».
  const subjectsProgress = await getSubjectProgressList(c.env.DB, uid, grade);
  const recommended = subjectsProgress
    .filter((r) => r.status === 'inProgress')
    .slice(0, 2)
    .map((r) => r.nameFa);
  const overall = averagePercent(subjectsProgress);

  // «ادامهٔ یادگیری» — فهرست چندمضمونی به‌جای یک درسِ ثابت (رفع اشکال:
  // قبلاً همیشه فقط اولین مضمون برنامهٔ درسی نشان داده می‌شد).
  const continueLearning = await buildContinueLearning(c.env.DB, uid, grade, subjectsProgress);
  const first = continueLearning[0];

  // امتحان پیش رو: اولین امتحان منتشرشدهٔ این صنف که شاگرد هنوز آن را نداده
  // است (رفع اشکال: قبلاً «آخرین امتحانِ ساخته‌شده» را نشان می‌داد، حتی اگر
  // شاگرد قبلاً همان را داده باشد — یعنی هیچ‌وقت واقعاً «پیش رو» نبود).
  const exam = await c.env.DB.prepare(
    `SELECT title FROM exams
      WHERE grade_number=? AND status='published'
        AND id NOT IN (SELECT exam_id FROM exam_attempts WHERE user_id=?)
      ORDER BY created_at ASC LIMIT 1`,
  )
    .bind(grade, uid)
    .first<{ title: string }>();
  const seminar = await c.env.DB.prepare(
    "SELECT title, scheduled_start FROM seminars WHERE audience='students' AND status IN ('published','registrationClosed','live') ORDER BY scheduled_start LIMIT 1",
  ).first<{ title: string; scheduled_start: string }>();

  // خلاصهٔ امتیاز فعالیت (Gamification) — برای نشان دادن نشان/سطح در خانهٔ شاگرد.
  const points = await getPointsSummary(c.env.DB, uid);

  // تعداد گواهی‌نامه‌های صادرشده — تا کارت «گواهی‌نامه‌های من» در خانهٔ شاگرد
  // به‌جای متن ثابت، وضعیت واقعی را نشان دهد.
  const certCount = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM certificates WHERE student_id=?')
    .bind(uid)
    .first<{ n: number }>();

  return c.json({
    studentDisplayName: u?.first_name ?? '',
    overallProgressPercent: overall,
    currentLessonTitle: first?.lessonTitle ?? 'درسی برای شروع موجود نیست',
    currentSubjectNameFa: first?.subjectNameFa ?? '',
    continueLearning,
    upcomingExamTitle: exam?.title ?? null,
    upcomingExamDate: null,
    upcomingSeminarTitle: seminar?.title ?? null,
    upcomingSeminarDate: seminar?.scheduled_start ?? null,
    recommendedTopics: recommended,
    pointsTotal: points.totalPoints,
    pointsLevel: points.level,
    pointsLevelTitleFa: points.levelTitleFa,
    // رفع اشکال: `getPointsSummary` این سه فیلد را از قبل محاسبه می‌کرد
    // (پیشرفت تا سطح بعدی) ولی اینجا هرگز به کلاینت فرستاده نمی‌شدند — یعنی
    // خانهٔ شاگرد امکان نمایش «چند امتیاز تا سطح بعدی» را نداشت، هرچند
    // دادهٔ آن روی سرور آماده بود.
    pointsNextLevelAt: points.nextLevelAt,
    pointsNextLevelTitleFa: points.nextLevelTitleFa,
    pointsProgressToNextPercent: points.progressToNextPercent,
    certificatesCount: certCount?.n ?? 0,
  });
});

// ─────────────────────── امتیاز فعالیت شاگرد (Gamification) ───────────────
// دسترسی: خود شاگرد، Super Admin، یا والدِ لینک‌شدهٔ تأییدشده به این شاگرد.

async function canViewStudentPoints(c: any, uid: string, role: string, studentId: string): Promise<boolean> {
  if (uid === studentId) return true;
  if (role === 'super_admin') return true;
  if (role === 'parent') {
    const link = await c.env.DB.prepare(
      "SELECT 1 FROM parent_student_links WHERE parent_user_id=? AND student_user_id=? AND status='approved'",
    )
      .bind(uid, studentId)
      .first();
    return !!link;
  }
  return false;
}

c11m.get('/students/me/points', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const points = await getPointsSummary(c.env.DB, uid);
  return c.json({ points });
});

c11m.get('/students/:studentId/points', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const uid = (payload?.['sub'] as string | undefined) ?? null;
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const role = (payload?.['role'] as string | undefined) ?? 'student';
  const studentId = c.req.param('studentId');
  if (!(await canViewStudentPoints(c, uid, role, studentId))) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  }
  const points = await getPointsSummary(c.env.DB, studentId);
  return c.json({ points });
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
    // چند فصل از این کتاب در نصاب داشبورد شاگردان منتشر شده — تا «مدیریت
    // معلم هوشمند» بتواند وضعیت هماهنگی را نشان دهد (کتاب آپلود شده اما
    // هنوز فصل‌بندی نشده = ۰؛ باید با «بازسازی نصاب» رفع شود).
    chapterCount: r.chapter_count ?? 0,
  };
}

// کوئری پایه — تعداد فصل‌های منتشرشدهٔ همین کتاب را هم برمی‌گرداند
// (source_book_id در chapters، از migration 0017).
const LIBRARY_BOOK_SELECT = `
  SELECT b.*, (SELECT COUNT(*) FROM chapters ch WHERE ch.source_book_id = b.id) AS chapter_count
  FROM curriculum_library_books b`;

c11m.get('/curriculum-library/books', async (c) => {
  if (!(await userId(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const { results } = await c.env.DB.prepare(
    `${LIBRARY_BOOK_SELECT} ORDER BY b.uploaded_at DESC`,
  ).all<any>();
  return c.json({ books: results.map(libraryBookJson) });
});

c11m.get('/curriculum-library/subjects/:subjectId/books', async (c) => {
  if (!(await userId(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const { results } = await c.env.DB.prepare(
    `${LIBRARY_BOOK_SELECT} WHERE b.subject_id = ? ORDER BY b.uploaded_at DESC`,
  )
    .bind(c.req.param('subjectId'))
    .all<any>();
  return c.json({ books: results.map(libraryBookJson) });
});

c11m.post('/curriculum-library/books', async (c) => {
  if (!(await isAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req
    .json<{ subjectId?: string; title?: string; pageCount?: number; gradeId?: number; extractedText?: string }>()
    .catch(() => null);
  const subjectId = String(b?.subjectId ?? '').trim();
  const title = String(b?.title ?? '').trim();
  if (!subjectId || !title) {
    return c.json(fail('BAD_REQUEST', 'مضمون و عنوان لازم است', 'Missing fields', 'مضمون او سرلیک اړین دي', 'La matière et le titre sont requis'), 400);
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

// رفع اشکال ناهماهنگی: قبلاً این Endpoint فقط ردیف کتابخانه را حذف می‌کرد —
// فصل/درس‌های منتشرشدهٔ همان کتاب (`chapters`/`lessons`، که نصاب داشبورد
// شاگردان دقیقاً از همان‌ها می‌خواند، نه از `curriculum_library_books`)
// دست‌نخورده می‌ماندند، پس مدیر کتاب را «حذف» می‌کرد ولی شاگردان همچنان
// همان درس‌ها را می‌دیدند. حالا حذف کتاب، فصل/درس‌های وابسته (و
// بازدید/تکمیل/نمایه‌سازی معنایی مرتبط) را هم به همان شکلی که در
// `applyChapterPublish` (backend/src/routes/admin.ts) هنگام جایگزینی
// انجام می‌شود، پاک می‌کند.
c11m.delete('/curriculum-library/books/:id', async (c) => {
  if (!(await isAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const bookId = c.req.param('id');

  const { results: chapters } = await c.env.DB.prepare('SELECT id FROM chapters WHERE source_book_id = ?')
    .bind(bookId)
    .all<{ id: string }>();
  if (chapters.length) {
    const chIds = chapters.map((r) => r.id);
    const chPh = chIds.map(() => '?').join(',');
    const { results: lessons } = await c.env.DB.prepare(`SELECT id FROM lessons WHERE chapter_id IN (${chPh})`)
      .bind(...chIds)
      .all<{ id: string }>();
    if (lessons.length) {
      const lsIds = lessons.map((r) => r.id);
      const lsPh = lsIds.map(() => '?').join(',');
      await c.env.DB.prepare(`DELETE FROM student_lesson_views WHERE lesson_id IN (${lsPh})`).bind(...lsIds).run();
      try {
        await c.env.DB.prepare(`DELETE FROM lesson_embeddings WHERE lesson_id IN (${lsPh})`).bind(...lsIds).run();
      } catch (_) {
        // جدول ممکن است هنوز مهاجرت نشده باشد.
      }
      await c.env.DB.prepare(`DELETE FROM lessons WHERE id IN (${lsPh})`).bind(...lsIds).run();
    }
    await c.env.DB.prepare(`DELETE FROM student_chapter_completions WHERE chapter_id IN (${chPh})`).bind(...chIds).run();
    await c.env.DB.prepare(`DELETE FROM chapters WHERE id IN (${chPh})`).bind(...chIds).run();
  }

  await c.env.DB.prepare('DELETE FROM curriculum_library_books WHERE id = ?').bind(bookId).run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: await adminId(c),
      actorRole: 'super_admin',
      actionType: 'content_delete',
      targetTable: 'curriculum_library_books',
      targetId: bookId,
      afterValue: { deletedChapters: chapters.length },
      ipAddress: clientIp(c),
      priority: 'high',
    }),
  );
  return c.json({ success: true, deletedChapters: chapters.length });
});

// ═══════════════════ مدیریت دستیِ درس‌ها (رفع اشکال «مدیریت محتوا > دروس») ═══
// قبلاً تب «دروس» در CMS مدیر فقط به جدول جداگانه و بی‌اثر `cms_lessons`
// می‌نوشت که هیچ شاگردی هرگز نمی‌دید — نصاب واقعی که شاگردان می‌بینند
// همیشه از `lessons`/`chapters` (بالا) خوانده می‌شود. این Endpointها به
// همان جدول‌های واقعی می‌نویسند (علاوه بر مسیر اصلیِ افزودن محتوا که
// بارگذاری/استخراج خودکار کتاب در «کتابخانهٔ نصاب» است) تا مدیر بتواند
// یک درسِ تکی را هم سریع دستی اضافه/ویرایش/حذف کند.

function lessonAdminJson(r: any) {
  return {
    id: r.id,
    title: r.title_fa,
    gradeNumber: r.grade_number,
    subjectId: r.subject_id,
    chapterId: r.chapter_id,
    chapterTitle: r.chapter_title_fa,
    durationMinutes: r.estimated_minutes,
    content: r.content_body,
    status: r.status,
    updatedAt: r.updated_at,
  };
}

const ADMIN_LESSON_SELECT = `SELECT l.id, l.title_fa, l.estimated_minutes, l.content_body, l.status, l.updated_at,
    l.chapter_id, ch.title_fa AS chapter_title_fa, ch.grade_number, ch.subject_id
  FROM lessons l JOIN chapters ch ON ch.id = l.chapter_id`;

c11m.get('/admin/curriculum/lessons', async (c) => {
  if (!(await isAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const { results } = await c.env.DB.prepare(`${ADMIN_LESSON_SELECT} ORDER BY l.updated_at DESC`).all<any>();
  return c.json({ lessons: results.map(lessonAdminJson) });
});

c11m.post('/admin/curriculum/lessons', async (c) => {
  if (!(await isAdmin(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req
    .json<{
      id?: string;
      gradeNumber?: number;
      subjectId?: string;
      chapterTitle?: string;
      title?: string;
      durationMinutes?: number;
      content?: string;
      status?: string;
    }>()
    .catch(() => null);
  const gradeNumber = Number(b?.gradeNumber ?? 0);
  const subjectId = String(b?.subjectId ?? '').trim();
  const chapterTitle = String(b?.chapterTitle ?? '').trim();
  const title = String(b?.title ?? '').trim();
  if (!gradeNumber || !subjectId || !chapterTitle || !title) {
    return c.json(fail('BAD_REQUEST', 'صنف، مضمون، عنوان فصل و عنوان درس لازم است', 'Missing fields', 'ټولګی، مضمون، د فصل سرلیک او د درس سرلیک اړین دي', 'La classe, la matière, le titre du chapitre et le titre de la leçon sont requis'), 400);
  }
  const status = b?.status === 'published' ? 'published' : 'draft';
  const durationMinutes = Number(b?.durationMinutes ?? 15);
  const content = String(b?.content ?? '');

  // فصل را پیدا کن یا بساز (بر اساس صنف+مضمون+عنوان — بدون کتاب مبدأ خاص).
  let chapter = await c.env.DB.prepare(
    'SELECT id FROM chapters WHERE grade_number = ? AND subject_id = ? AND title_fa = ?',
  )
    .bind(gradeNumber, subjectId, chapterTitle)
    .first<{ id: string }>();
  let chapterId: string;
  if (chapter) {
    chapterId = chapter.id;
  } else {
    const countRow = await c.env.DB.prepare(
      'SELECT COUNT(*) AS n FROM chapters WHERE grade_number = ? AND subject_id = ?',
    )
      .bind(gradeNumber, subjectId)
      .first<{ n: number }>();
    chapterId = `ch_manual_${crypto.randomUUID()}`;
    await c.env.DB.prepare(
      'INSERT INTO chapters (id, grade_number, subject_id, title_fa, order_index, status) VALUES (?, ?, ?, ?, ?, ?)',
    )
      .bind(chapterId, gradeNumber, subjectId, chapterTitle, (countRow?.n ?? 0) + 1, 'published')
      .run();
  }

  const id = b?.id && String(b.id).trim().length > 0 ? String(b.id).trim() : `ls_manual_${crypto.randomUUID()}`;
  const existing = await c.env.DB.prepare('SELECT id FROM lessons WHERE id = ?').bind(id).first();
  if (existing) {
    await c.env.DB.prepare(
      `UPDATE lessons SET chapter_id = ?, title_fa = ?, estimated_minutes = ?, content_body = ?, status = ?,
         updated_at = datetime('now') WHERE id = ?`,
    )
      .bind(chapterId, title, durationMinutes, content, status, id)
      .run();
  } else {
    const orderRow = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM lessons WHERE chapter_id = ?')
      .bind(chapterId)
      .first<{ n: number }>();
    await c.env.DB.prepare(
      `INSERT INTO lessons (id, chapter_id, title_fa, estimated_minutes, order_index, content_body, status, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
    )
      .bind(id, chapterId, title, durationMinutes, (orderRow?.n ?? 0) + 1, content, status)
      .run();
  }

  const row = await c.env.DB.prepare(`${ADMIN_LESSON_SELECT} WHERE l.id = ?`).bind(id).first<any>();
  return c.json({ lesson: lessonAdminJson(row) });
});

c11m.patch('/admin/curriculum/lessons/:id/status', async (c) => {
  const admin = await adminId(c);
  if (!admin) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  const status = b?.status === 'published' ? 'published' : 'draft';
  const id = c.req.param('id');
  await c.env.DB.prepare("UPDATE lessons SET status = ?, updated_at = datetime('now') WHERE id = ?")
    .bind(status, id)
    .run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: admin,
      actorRole: 'super_admin',
      actionType: 'content_status_change',
      targetTable: 'lessons',
      targetId: id,
      afterValue: { status },
      ipAddress: clientIp(c),
    }),
  );
  return c.json({ success: true });
});

c11m.delete('/admin/curriculum/lessons/:id', async (c) => {
  const admin = await adminId(c);
  if (!admin) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const id = c.req.param('id');
  await c.env.DB.prepare('DELETE FROM student_lesson_views WHERE lesson_id = ?').bind(id).run();
  try {
    await c.env.DB.prepare('DELETE FROM lesson_embeddings WHERE lesson_id = ?').bind(id).run();
  } catch (_) {
    // جدول ممکن است هنوز مهاجرت نشده باشد.
  }
  await c.env.DB.prepare('DELETE FROM lessons WHERE id = ?').bind(id).run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: admin,
      actorRole: 'super_admin',
      actionType: 'content_delete',
      targetTable: 'lessons',
      targetId: id,
      ipAddress: clientIp(c),
      priority: 'high',
    }),
  );
  return c.json({ success: true });
});

export default c11m;
