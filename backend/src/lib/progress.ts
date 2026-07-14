/**
 * lib/progress.ts — منبع واحد محاسبهٔ «پیشرفت درسی» و «امتیاز فعالیت شاگرد».
 *
 * چرا این فایل لازم است؟ قبلاً محاسبهٔ فیصدی پیشرفت هر مضمون در ۵ جای مختلف
 * (grade-map، dashboard-summary، parents/children/summary، admin/students/:id،
 * admin/students/:id/ai-report) هرکدام با یک کوئری SQL جداگانه تکرار شده بود؛
 * این یعنی هر لحظه امکان داشت عددها در داشبورد شاگرد، والد و مدیر باهم فرق
 * کنند. از این پس همه از همین چند تابع استفاده می‌کنند تا عدد پیشرفت *دقیقاً*
 * یکسان در هر سه داشبورد نمایش داده شود.
 */

export type SubjectProgress = {
  subjectId: string;
  nameFa: string;
  totalLessons: number;
  viewedLessons: number;
  percent: number; // 0..100 با یک رقم اعشار
  status: 'locked' | 'inProgress' | 'completed';
};

/** پیشرفت هر مضمون برای یک شاگرد در یک صنف — منبع واحد حقیقت برای همهٔ داشبوردها. */
export async function getSubjectProgressList(
  db: D1Database,
  studentId: string,
  grade: number,
): Promise<SubjectProgress[]> {
  const { results } = await db
    .prepare(
      `SELECT s.id AS subject_id, s.name_fa,
         (SELECT COUNT(*) FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
            WHERE ch.subject_id=s.id AND ch.grade_number=? AND l.status='published' AND ch.status='published') AS total,
         (SELECT COUNT(*) FROM lessons l JOIN chapters ch ON ch.id=l.chapter_id
            JOIN student_lesson_views v ON v.lesson_id=l.id AND v.user_id=?
            WHERE ch.subject_id=s.id AND ch.grade_number=? AND l.status='published' AND ch.status='published') AS viewed
       FROM subjects s ORDER BY s.order_index`,
    )
    .bind(grade, studentId, grade)
    .all<{ subject_id: string; name_fa: string; total: number; viewed: number }>();

  return results.map((r) => {
    const percent = r.total > 0 ? Math.round((r.viewed / r.total) * 1000) / 10 : 0;
    let status: SubjectProgress['status'] = 'locked';
    if (r.total > 0 && r.viewed >= r.total) status = 'completed';
    else if (r.viewed > 0) status = 'inProgress';
    return {
      subjectId: r.subject_id,
      nameFa: r.name_fa,
      totalLessons: r.total,
      viewedLessons: r.viewed,
      percent,
      status,
    };
  });
}

/** میانگین فیصدی پیشرفت همهٔ مضامین (برای «پیشرفت کلی صنف»). */
export function averagePercent(list: SubjectProgress[]): number {
  if (!list.length) return 0;
  const sum = list.reduce((a, r) => a + r.percent, 0);
  return Math.round((sum / list.length) * 10) / 10;
}

export type ChapterProgress = {
  id: string;
  titleFa: string;
  orderIndex: number;
  lessonCount: number;
  viewedCount: number;
  percent: number;
  completed: boolean;
  unlocked: boolean;
  sourceBookId: string | null;
};

/**
 * فصل‌های یک مضمون + وضعیت قفل ترتیبی: فصل اول همیشه باز است؛ فصل بعدی فقط
 * وقتی باز می‌شود که فصل قبلی به‌طور کامل («همهٔ درس‌ها دیده‌شده») تکمیل شده
 * باشد — دقیقاً منطقی که کاربر خواسته («یک فصل را تکمیل نکرده فصل بعدی باز نشود»).
 */
export async function getChapterList(
  db: D1Database,
  subjectId: string,
  grade: number,
  studentId: string | null,
): Promise<ChapterProgress[]> {
  const { results } = await db
    .prepare(
      `SELECT ch.id, ch.title_fa, ch.order_index, ch.source_book_id,
         (SELECT COUNT(*) FROM lessons l WHERE l.chapter_id=ch.id AND l.status='published') AS lesson_count,
         (SELECT COUNT(*) FROM lessons l JOIN student_lesson_views v ON v.lesson_id=l.id AND v.user_id=?
            WHERE l.chapter_id=ch.id AND l.status='published') AS viewed_count
       FROM chapters ch
       WHERE ch.subject_id=? AND ch.grade_number=? AND ch.status='published'
       ORDER BY ch.order_index`,
    )
    .bind(studentId ?? '', subjectId, grade)
    .all<{
      id: string;
      title_fa: string;
      order_index: number;
      source_book_id: string | null;
      lesson_count: number;
      viewed_count: number;
    }>();

  let previousCompleted = true; // فصل اول همیشه باز است
  return results.map((r) => {
    const completed = r.lesson_count > 0 && r.viewed_count >= r.lesson_count;
    const percent = r.lesson_count > 0 ? Math.round((r.viewed_count / r.lesson_count) * 1000) / 10 : 0;
    const unlocked = previousCompleted;
    previousCompleted = completed;
    return {
      id: r.id,
      titleFa: r.title_fa,
      orderIndex: r.order_index,
      lessonCount: r.lesson_count,
      viewedCount: r.viewed_count,
      percent,
      completed,
      unlocked,
      sourceBookId: r.source_book_id,
    };
  });
}

// ═══════════════════════ امتیازدهی بر اساس فعالیت (Gamification) ═══════════

export const POINTS_PER_LESSON_VIEW = 10;
export const POINTS_PER_CHAPTER_COMPLETE = 25;

export async function awardPoints(
  db: D1Database,
  studentId: string,
  points: number,
  reason: string,
  refId: string,
): Promise<void> {
  const id = `pt_${crypto.randomUUID()}`;
  await db
    .prepare('INSERT INTO student_points_ledger (id, student_id, points, reason, ref_id) VALUES (?, ?, ?, ?, ?)')
    .bind(id, studentId, points, reason, refId)
    .run();
}

export type PointsSummary = {
  totalPoints: number;
  level: number;
  levelTitleFa: string;
  nextLevelAt: number | null;
  nextLevelTitleFa: string | null;
  progressToNextPercent: number; // 0..100 — برای نوار پیشرفت سطح در پروفایل شاگرد
  recent: { points: number; reason: string; refId: string; createdAt: string }[];
};

export async function getPointsSummary(db: D1Database, studentId: string): Promise<PointsSummary> {
  const totalRow = await db
    .prepare('SELECT COALESCE(SUM(points),0) AS total FROM student_points_ledger WHERE student_id=?')
    .bind(studentId)
    .first<{ total: number }>();
  const total = totalRow?.total ?? 0;

  const { results: levels } = await db
    .prepare('SELECT level, min_points, title_fa FROM points_levels ORDER BY min_points')
    .all<{ level: number; min_points: number; title_fa: string }>();

  let current = levels[0] ?? { level: 1, min_points: 0, title_fa: 'نوآموز' };
  let next: { level: number; min_points: number; title_fa: string } | null = null;
  for (const lvl of levels) {
    if (lvl.min_points <= total) current = lvl;
    else {
      next = lvl;
      break;
    }
  }
  const progressToNextPercent = next
    ? Math.round(((total - current.min_points) / (next.min_points - current.min_points)) * 1000) / 10
    : 100;

  const { results: recentRows } = await db
    .prepare('SELECT points, reason, ref_id, created_at FROM student_points_ledger WHERE student_id=? ORDER BY created_at DESC LIMIT 20')
    .bind(studentId)
    .all<{ points: number; reason: string; ref_id: string; created_at: string }>();

  return {
    totalPoints: total,
    level: current.level,
    levelTitleFa: current.title_fa,
    nextLevelAt: next?.min_points ?? null,
    nextLevelTitleFa: next?.title_fa ?? null,
    progressToNextPercent,
    recent: recentRows.map((r) => ({ points: r.points, reason: r.reason, refId: r.ref_id, createdAt: r.created_at })),
  };
}

/**
 * ثبت بازدید یک درس + اهدای امتیاز فعالیت + بررسی تکمیل فصل (که پایهٔ
 * قفل‌گشایی فصل بعدی است). idempotent است: بازدید تکراری امتیاز اضافه نمی‌دهد.
 */
export async function recordLessonView(
  db: D1Database,
  studentId: string,
  lessonId: string,
): Promise<{ found: boolean; firstView: boolean; chapterJustCompleted: boolean; chapterId: string | null }> {
  const lesson = await db
    .prepare("SELECT chapter_id FROM lessons WHERE id=? AND status='published'")
    .bind(lessonId)
    .first<{ chapter_id: string }>();
  if (!lesson) return { found: false, firstView: false, chapterJustCompleted: false, chapterId: null };

  const insertResult = await db
    .prepare('INSERT OR IGNORE INTO student_lesson_views (user_id, lesson_id) VALUES (?, ?)')
    .bind(studentId, lessonId)
    .run();
  const firstView = (insertResult.meta?.changes ?? 0) > 0;

  let chapterJustCompleted = false;
  if (firstView) {
    await awardPoints(db, studentId, POINTS_PER_LESSON_VIEW, 'lesson_view', lessonId);

    const chapterId = lesson.chapter_id;
    const counts = await db
      .prepare(
        `SELECT
           (SELECT COUNT(*) FROM lessons WHERE chapter_id=? AND status='published') AS total,
           (SELECT COUNT(*) FROM lessons l JOIN student_lesson_views v ON v.lesson_id=l.id AND v.user_id=?
              WHERE l.chapter_id=? AND l.status='published') AS viewed`,
      )
      .bind(chapterId, studentId, chapterId)
      .first<{ total: number; viewed: number }>();

    if (counts && counts.total > 0 && counts.viewed >= counts.total) {
      const already = await db
        .prepare('SELECT 1 FROM student_chapter_completions WHERE user_id=? AND chapter_id=?')
        .bind(studentId, chapterId)
        .first();
      if (!already) {
        await db
          .prepare('INSERT OR IGNORE INTO student_chapter_completions (user_id, chapter_id) VALUES (?, ?)')
          .bind(studentId, chapterId)
          .run();
        await awardPoints(db, studentId, POINTS_PER_CHAPTER_COMPLETE, 'chapter_complete', chapterId);
        chapterJustCompleted = true;
      }
    }
  }

  return { found: true, firstView, chapterJustCompleted, chapterId: lesson.chapter_id };
}
