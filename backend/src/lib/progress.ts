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

// ═══════════════════ ارتقای واقعی صنف (Server-Authoritative) ═══════════════
// رفع اشکال: قبلاً «تکمیل مضامین + کامیابی در امتحان» و ارتقای صنف فقط در
// یک ذخیرهٔ محلی روی گوشی (ProgressionStore) شبیه‌سازی می‌شد و هرگز به
// دیتابیس واقعی نمی‌رسید — یعنی با نصب مجدد یا روی گوشی دیگر از بین
// می‌رفت و با نصاب واقعی (همینجا محاسبه‌شده) هماهنگ نبود. از این پس صنف
// فعال (`users.current_grade`) فقط از همین‌جا و بر پایهٔ دادهٔ واقعی
// تغییر می‌کند.

/** حداقل نمرهٔ امتحان «نهایی» برای کامیابی و ارتقا (هماهنگ با kPromoteExamMark کلاینت). */
export const PROMOTION_EXAM_PASS_PERCENT = 80;

export type PromotionStatus = {
  allSubjectsComplete: boolean;
  examPassed: boolean;
  examBestScore: number | null;
  canPromote: boolean;
};

/**
 * وضعیت واجد شرایط بودن برای ارتقا — «همان دو شرط» که قبلاً فقط محلی
 * بررسی می‌شد، اکنون از دادهٔ واقعی سرور:
 *   ۱) تمام مضامینی که در این صنف محتوا دارند، ۱۰۰٪ دیده شده باشند.
 *   ۲) شاگرد حداقل یک امتحانِ «نهایی» منتشرشدهٔ همین صنف را با نمرهٔ
 *      ≥۸۰٪ داده باشد (هر مضمونی — طبق طراحی فاز ۱).
 */
export async function getPromotionStatus(
  db: D1Database,
  studentId: string,
  grade: number,
): Promise<PromotionStatus> {
  // رفع اشکال (H5 — همسویی معیارِ ارتقا با معیارِ واقعیِ قفلِ فصل/درس):
  // قبلاً اینجا از [getSubjectProgressList] استفاده می‌شد که «تکمیل» را فقط
  // از روی «دیده‌شدنِ درس» (percent >= 100) می‌سنجد — یعنی شاگردی که هرگز
  // «یاد گرفتم» نزده، کار خانگی نداده، یا آزمونِ هیچ فصلی را نداده بود هم
  // می‌توانست فقط با بازکردنِ صفحهٔ همهٔ درس‌ها واجدِ شرایطِ ارتقا شود؛ در
  // حالی‌که خودِ قفلِ فصل ([getChapterList]) معیارِ بسیار سخت‌گیرانه‌تری
  // (یاد گرفتم + کار خانگی + در صورت وجود، آزمونِ فصل) دارد. `percent` فقط
  // برای نوارهای پیشرفتِ نمایشی در داشبوردها همان تعریفِ قدیمی («دیده‌شده»)
  // را نگه می‌دارد؛ ارتقا از این پس مستقیماً از همان معیارِ سخت‌گیرانه‌ای
  // استفاده می‌کند که خودِ فصل/درس را باز می‌کند.
  const { results: subjects } = await db.prepare('SELECT id FROM subjects ORDER BY order_index').all<{ id: string }>();
  let anySubjectHasContent = false;
  let allSubjectsComplete = true;
  for (const s of subjects) {
    const chapters = await getChapterList(db, s.id, grade, studentId);
    if (chapters.length === 0) continue; // این مضمون در این صنف اصلاً محتوا ندارد.
    anySubjectHasContent = true;
    if (!chapters.every((ch) => ch.completed)) {
      allSubjectsComplete = false;
      break;
    }
  }
  allSubjectsComplete = anySubjectHasContent && allSubjectsComplete;

  // رفع اشکال «امتحان فاینل تک‌مضمونه»: امتحان نهایی از این پس یک امتحان
  // چندمضمونهٔ واحد برای کل صنف است (migration 0041: final_exams/
  // final_exam_attempts)، نه یک ردیف جداگانه در `exams` به‌ازای هر مضمون.
  // منطق و آستانهٔ قبولی (PROMOTION_EXAM_PASS_PERCENT) کاملاً همان قبلی است.
  const bestRow = await db
    .prepare(
      `SELECT MAX(a.score_percent) AS best FROM final_exam_attempts a
       JOIN final_exams e ON e.id = a.final_exam_id
       WHERE a.user_id = ? AND e.grade_number = ? AND e.status = 'published'`,
    )
    .bind(studentId, grade)
    .first<{ best: number | null }>();
  const examBestScore = bestRow?.best ?? null;
  const examPassed = (examBestScore ?? 0) >= PROMOTION_EXAM_PASS_PERCENT;

  return {
    allSubjectsComplete,
    examPassed,
    examBestScore,
    canPromote: allSubjectsComplete && examPassed,
  };
}

/**
 * اگر شاگرد واجد شرایط باشد، صنف فعال را واقعاً (روی دیتابیس) یک پله بالا
 * می‌برد. Idempotent و بی‌خطر است — اگر واجد شرایط نباشد یا در بالاترین
 * صنف (۱۲) باشد، کاری نمی‌کند.
 */
export async function promoteIfEligible(
  db: D1Database,
  studentId: string,
): Promise<{ promoted: boolean; newGrade: number | null }> {
  const student = await db.prepare('SELECT current_grade FROM users WHERE id = ?').bind(studentId).first<{
    current_grade: number | null;
  }>();
  const grade = student?.current_grade ?? 7;
  if (grade >= 12) return { promoted: false, newGrade: null };

  const status = await getPromotionStatus(db, studentId, grade);
  if (!status.canPromote) return { promoted: false, newGrade: null };

  const newGrade = grade + 1;
  await db.prepare('UPDATE users SET current_grade = ? WHERE id = ?').bind(newGrade, studentId).run();
  return { promoted: true, newGrade };
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
  // رفع اشکال: قبلاً hasQuiz/quizSubmitted فقط داخل این تابع محاسبه می‌شدند
  // (برای تصمیم completed/unlocked) ولی هرگز به کلاینت فرستاده نمی‌شدند —
  // یعنی شاگرد بعد از دیدن همهٔ درس‌های یک فصل که آزمونش ساخته شده، هیچ
  // نشانه یا راهی برای رفتن به «آزمون فصل» نمی‌دید (پیشرفت ۱۰۰٪ ولی فصل
  // هرگز completed نمی‌شد و هیچ دکمه‌ای هم نبود). این پرچم دقیقاً همان لحظه
  // را مشخص می‌کند: آزمون ساخته شده ولی هنوز ارسال نشده.
  quizPending: boolean;
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
            WHERE l.chapter_id=ch.id AND l.status='published') AS viewed_count,
         (SELECT COUNT(*) FROM lessons l WHERE l.chapter_id=ch.id AND l.status='published'
            AND EXISTS (SELECT 1 FROM student_lesson_views v WHERE v.lesson_id=l.id AND v.user_id=?)
            -- رفع اشکال امنیتی/منطقی (migration 0050): «کار خانگی وجود ندارد»
            -- فقط وقتی fail-safe حساب می‌شود که شاگرد واقعاً دکمهٔ «یاد گرفتم»
            -- را زده باشد — وگرنه شاگردی که هرگز این دکمه را نمی‌زند هم با
            -- همین Fail-safe به‌اشتباه «تکمیل‌شده» حساب می‌شد. نگاه کنید به
            -- کامنتِ کامل در [getLessonLockList] پایین همین فایل.
            AND EXISTS (SELECT 1 FROM student_lesson_learned ll WHERE ll.lesson_id=l.id AND ll.student_id=?)
            AND COALESCE(
              (SELECT h.status FROM student_homeworks h WHERE h.student_id=? AND h.lesson_id=l.id
                 ORDER BY h.created_at DESC LIMIT 1),
              'submitted'
            ) IN ('submitted','graded')
         ) AS fully_completed_count,
         (SELECT cq.id FROM chapter_quizzes cq WHERE cq.chapter_id=ch.id AND cq.status='published') AS quiz_id,
         (SELECT COUNT(*) FROM chapter_quiz_attempts qa JOIN chapter_quizzes cq2 ON cq2.id=qa.quiz_id
            WHERE cq2.chapter_id=ch.id AND qa.user_id=?) AS quiz_attempted_count
       FROM chapters ch
       WHERE ch.subject_id=? AND ch.grade_number=? AND ch.status='published'
       ORDER BY ch.order_index`,
    )
    .bind(studentId ?? '', studentId ?? '', studentId ?? '', studentId ?? '', studentId ?? '', subjectId, grade)
    .all<{
      id: string;
      title_fa: string;
      order_index: number;
      source_book_id: string | null;
      lesson_count: number;
      viewed_count: number;
      fully_completed_count: number;
      quiz_id: string | null;
      quiz_attempted_count: number;
    }>();

  let previousCompleted = true; // فصل اول همیشه باز است
  return results.map((r) => {
    // رفع اشکال/بازطراحی (طبق درخواست صاحب پروژه): اگر برای این فصل یک
    // «آزمون فصل» با هوش مصنوعی ساخته و منتشر شده باشد (migration 0041 —
    // lib/chapterQuiz.ts::ensureChapterQuiz، خودکار بعد از دیدن همهٔ درس‌ها)،
    // معیار «تکمیل» دیگر صرفِ دیدن درس‌ها نیست، بلکه ارسال همان آزمون است —
    // فصل بعدی فقط بعد از سپری‌کردن امتحان فصل باز می‌شود. اگر (به هر دلیلی،
    // مثلاً هوش مصنوعی پیکربندی نشده) هیچ آزمونی برای این فصل ساخته نشده،
    // fail-safe به‌جای «همهٔ درس‌ها دیده‌شده» حالا از همان معیارِ یکپارچهٔ
    // «تکمیلِ درس» استفاده می‌کند که [getLessonLockList]/[checkAndCompleteChapter]
    // هم استفاده می‌کنند (دیده‌شده + کار خانگی ارسال/نمره‌داده‌شده، یا نبودِ
    // کار خانگی) — رفع اشکالِ ریشه‌ایِ «فصل قبل از خواندنِ واقعیِ درس‌ها
    // تکمیل‌شده اعلام می‌شد»: قبلاً همین‌که همهٔ درس‌ها فقط «دیده» می‌شدند
    // (حتی صرفِ بازکردنِ صفحه، بدون خواندن/چت/کار خانگی) کافی بود.
    const hasQuiz = r.quiz_id != null;
    const quizSubmitted = (r.quiz_attempted_count ?? 0) > 0;
    // رفع اشکالِ ریشه‌ای («آزمونِ فصل قبل از خواندنِ حتی یک درس آماده نشان
    // داده می‌شود»): `chapter_quizzes` یک ردیفِ *مشترک برای کل فصل* است —
    // یک‌بار توسط هر شاگردی که اول به آخر فصل برسد ساخته می‌شود و از آن پس
    // برای همهٔ شاگردانِ همان فصل (حتی آن‌هایی که هنوز هیچ درسی از این فصل
    // را نخوانده‌اند) در جدول موجود است؛ نگاه کنید به کامنتِ بالای
    // `ensureChapterQuiz` در `lib/chapterQuiz.ts`. پس صرفِ «آزمون برای این
    // فصل وجود دارد» هرگز نباید به‌معنیِ «این شاگردِ خاص برای آزمون آماده
    // است» باشد — وگرنه دقیقاً همان چیزی رخ می‌دهد که گزارش شد: شاگردی که
    // درسِ اول را هم باز نکرده، با «آزمون فصل آماده است» روبه‌رو می‌شود. حالا
    // این معیار هم اضافه شده: فقط وقتی *خودِ همین شاگرد* همهٔ درس‌های فصل را
    // به‌طور کامل (دیده + کار خانگی ارسال/نمره‌داده‌شده) تمام کرده باشد، وجودِ
    // آزمون به‌معنیِ «آماده/در انتظار» حساب می‌شود.
    const lessonsFullyDone = r.lesson_count > 0 && r.fully_completed_count >= r.lesson_count;
    const quizPending = hasQuiz && lessonsFullyDone && !quizSubmitted;
    const completed = hasQuiz ? lessonsFullyDone && quizSubmitted : lessonsFullyDone;
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
      quizPending,
    };
  });
}

// ═══════════════ قفل زنجیره‌ای دروس (Prerequisite Locking System) ═══════════
// 🔒 قانون قفل: هیچ شاگردی به درس بعدی دسترسی ندارد مگر درس قبلی ۱۰۰٪ تکمیل
// شده باشد — یعنی «متن درس را یاد گرفتم» زده شده (که همان لحظه کار خانگی
// ساخته می‌شود) و کار خانگی مربوطه با موفقیت ثبت (submitted/graded) شده باشد.
//
// نکتهٔ Fail-safe (مستند برای تیم): اگر برای درسی اصلاً رکورد کار خانگی وجود
// نداشته باشد (مثلاً تولید Gemini در لحظهٔ «یاد گرفتم» به‌خاطر اتمام سهمیهٔ
// رایگان ناموفق بود)، همان «دیده‌شدن درس» شرط تکمیل حساب می‌شود — شاگرد
// هرگز به‌خاطر خطای سرویس بیرونی برای همیشه پشت قفل نمی‌ماند.
//
// 🔒 رفع اشکال امنیتی (migration 0050 — «دورزدنِ قفل با هرگز نزدنِ یاد
// گرفتم»): Fail-safeِ بالا («کار خانگی نبود = مشکلی نیست») قبلاً هیچ راهی
// نداشت که «شاگرد هرگز دکمهٔ یاد گرفتم را نزده» را از «زده ولی هوش مصنوعی
// خطا داد» تشخیص دهد — چون کار خانگی *فقط* از داخل همان دکمه ساخته می‌شود
// (POST /lessons/:lessonId/learned، lib/lessonHomework.ts). نتیجه: شاگردی
// که فقط صفحهٔ درس را باز می‌کرد (بدون خواندن/چت/یاد گرفتم) هم با همین
// Fail-safe به‌اشتباه «تکمیل‌شده» حساب می‌شد و کل فصل را دور می‌زد. از این
// پس خودِ رویدادِ «یاد گرفتم» مستقیماً در جدول `student_lesson_learned`
// ثبت می‌شود (صرف‌نظر از موفقیتِ ساختِ کار خانگی) و همین ردیف، شرط جدیدِ
// جداگانهٔ «تکمیل» است — Fail-safeِ کار خانگی فقط *بعد از* وجود این ردیف
// اعمال می‌شود.
//
// 🚨 این بخش یک لایهٔ *جدید و جداگانه* است: هیچ تغییری در محاسبهٔ فیصدی
// پیشرفت، امتیازدهی، یا منطق «یاد گرفتم ← کار خانگی» (بالا/پایین همین فایل)
// نمی‌دهد — فقط از روی همان داده‌ها وضعیت باز/قفل را «می‌خواند».

/** وضعیت قفل/تکمیل یک درس در زنجیره. */
export type LessonLockInfo = {
  id: string;
  orderIndex: number;
  viewed: boolean;
  /** «یاد گرفتم» + کار خانگی ثبت‌شده (یا نبود کار خانگی — Fail-safe بالا). */
  completed: boolean;
  unlocked: boolean;
};

/**
 * وضعیت قفل تمام درس‌های یک فصل برای یک شاگرد — منبع واحد حقیقت برای همهٔ
 * داشبوردها (شاگرد/معلم/مدیر) تا آیکون قفل همه‌جا یکسان باشد.
 *
 * `chapterUnlocked` از [getChapterList] می‌آید: اگر خود فصل قفل باشد، همهٔ
 * درس‌هایش قفل‌اند؛ در فصل باز، درس اول باز است و هر درس بعدی فقط بعد از
 * تکمیل درس قبلی باز می‌شود.
 */
export async function getLessonLockList(
  db: D1Database,
  chapterId: string,
  studentId: string | null,
  chapterUnlocked: boolean,
): Promise<LessonLockInfo[]> {
  const { results } = await db
    .prepare(
      `SELECT l.id, l.order_index,
         CASE WHEN v.lesson_id IS NULL THEN 0 ELSE 1 END AS viewed,
         CASE WHEN ll.lesson_id IS NULL THEN 0 ELSE 1 END AS learned,
         (SELECT h.status FROM student_homeworks h
            WHERE h.student_id = ? AND h.lesson_id = l.id
            ORDER BY h.created_at DESC LIMIT 1) AS hw_status
       FROM lessons l
       LEFT JOIN student_lesson_views v ON v.lesson_id = l.id AND v.user_id = ?
       LEFT JOIN student_lesson_learned ll ON ll.lesson_id = l.id AND ll.student_id = ?
       WHERE l.chapter_id = ? AND l.status = 'published'
       ORDER BY l.order_index`,
    )
    .bind(studentId ?? '', studentId ?? '', studentId ?? '', chapterId)
    .all<{ id: string; order_index: number; viewed: number; learned: number; hw_status: string | null }>();

  let previousCompleted = true; // درس اولِ فصلِ باز، همیشه باز است
  return results.map((r) => {
    const viewed = r.viewed === 1;
    // رفع اشکال امنیتی (migration 0050): «تکمیل» دیگر صرفِ دیده‌شدن نیست —
    // باید خودِ «یاد گرفتم» هم واقعاً زده شده باشد؛ نگاه کنید به کامنتِ کامل
    // بالای این تابع.
    const learned = r.learned === 1;
    const homeworkDone = r.hw_status === null || r.hw_status === 'submitted' || r.hw_status === 'graded';
    const completed = learned && homeworkDone;
    const unlocked = chapterUnlocked && previousCompleted;
    previousCompleted = completed;
    return { id: r.id, orderIndex: r.order_index, viewed, completed, unlocked };
  });
}

/**
 * بررسی سرور-محورِ باز بودن یک درس مشخص برای یک شاگرد — نگهبان Endpointهای
 * درس (GET /lessons/:id، POST view/learned). null یعنی درس یافت نشد.
 */
export async function isLessonUnlockedFor(
  db: D1Database,
  studentId: string,
  lessonId: string,
): Promise<{ found: boolean; unlocked: boolean }> {
  const lesson = await db
    .prepare(
      `SELECT l.chapter_id, ch.subject_id, ch.grade_number
         FROM lessons l JOIN chapters ch ON ch.id = l.chapter_id
        WHERE l.id = ? AND l.status = 'published'`,
    )
    .bind(lessonId)
    .first<{ chapter_id: string; subject_id: string; grade_number: number }>();
  if (!lesson) return { found: false, unlocked: false };

  const chapterList = await getChapterList(db, lesson.subject_id, lesson.grade_number, studentId);
  const chapter = chapterList.find((ch) => ch.id === lesson.chapter_id);
  const chapterUnlocked = chapter?.unlocked ?? true;

  const locks = await getLessonLockList(db, lesson.chapter_id, studentId, chapterUnlocked);
  const info = locks.find((l) => l.id === lessonId);
  return { found: true, unlocked: info?.unlocked ?? false };
}

/**
 * بررسیِ متمرکز و یکپارچهٔ «آیا این فصل الان تکمیل شد؟» — منبعِ واحدِ
 * حقیقت که از هر دو نقطه‌ای صدا زده می‌شود که می‌تواند آخرین قطعهٔ ناقصِ
 * یک فصل را کامل کند: دیدنِ یک درس ([recordLessonView]) و ارسالِ کار خانگی
 * ([routes/homework.ts]::`POST /homework/:id/submit`).
 *
 * رفع اشکالِ ریشه‌ایِ گزارش‌شده («فصل تکمیل شد» قبل از خواندنِ واقعیِ درسِ
 * اول/تنها؛ یا همین‌که وارد یک درس می‌شود بلافاصله امتحان می‌آید): قبلاً
 * «تکمیلِ فصل» فقط از روی «همهٔ درس‌های فصل *دیده*‌شده‌اند» تصمیم می‌گرفت —
 * و این فقط داخل [recordLessonView] چک می‌شد، یعنی دقیقاً همان لحظه‌ای که
 * شاگرد صفحهٔ آخرین درسِ فصل را باز می‌کرد (حتی یک ثانیه، پیش از خواندنِ
 * واقعیِ متن، چت با معلم، زدنِ «یاد گرفتم»، یا فرستادنِ کار خانگیِ همان
 * درس)، سرور فوراً chapterJustCompleted=true برمی‌گرداند و کلاینت ۱.۴ ثانیه
 * بعد مستقیم به «آزمون فصل» می‌رفت. همین معیارِ «صرفِ دیده‌شدن» با معیارِ
 * قفلِ درس‌به‌درس ([getLessonLockList]: دیده‌شده + کار خانگی ارسال/نمره‌
 * داده‌شده) هم ناهماهنگ بود.
 *
 * قاعدهٔ یکپارچهٔ تازه: فصل فقط وقتی «تازه تکمیل شده» حساب می‌شود که
 * **همهٔ** درس‌های آن هم دیده‌شده و هم (کار خانگی‌شان ارسال/نمره‌داده‌شده یا
 * اصلاً کار خانگی‌ای برایشان ساخته نشده — همان Fail-safe موجود) باشند —
 * دقیقاً همان تعریفِ «تکمیلِ درس» که قفلِ درسِ بعدی از آن استفاده می‌کند. تا
 * وقتی این شرط برای آخرین درسِ فصل هم برقرار نشود (که معمولاً با فرستادنِ
 * کار خانگیِ همان درس، نه صرفِ بازکردنِ صفحه‌اش، اتفاق می‌افتد)،
 * chapterJustCompleted هرگز true برنمی‌گردد — پس جشن/هدایتِ خودکار به آزمونِ
 * فصل هم زودتر از موعد رخ نمی‌دهد.
 *
 * Idempotent: اگر فصل قبلاً تکمیل ثبت شده باشد (`student_chapter_completions`)،
 * دوباره امتیاز نمی‌دهد و chapterJustCompleted=false برمی‌گرداند.
 */
export async function checkAndCompleteChapter(
  db: D1Database,
  studentId: string,
  chapterId: string,
): Promise<{ chapterJustCompleted: boolean }> {
  const already = await db
    .prepare('SELECT 1 FROM student_chapter_completions WHERE user_id=? AND chapter_id=?')
    .bind(studentId, chapterId)
    .first();
  if (already) return { chapterJustCompleted: false };

  const { results } = await db
    .prepare(
      `SELECT l.id,
         CASE WHEN v.lesson_id IS NULL THEN 0 ELSE 1 END AS viewed,
         CASE WHEN ll.lesson_id IS NULL THEN 0 ELSE 1 END AS learned,
         (SELECT h.status FROM student_homeworks h
            WHERE h.student_id = ? AND h.lesson_id = l.id
            ORDER BY h.created_at DESC LIMIT 1) AS hw_status
       FROM lessons l
       LEFT JOIN student_lesson_views v ON v.lesson_id = l.id AND v.user_id = ?
       LEFT JOIN student_lesson_learned ll ON ll.lesson_id = l.id AND ll.student_id = ?
       WHERE l.chapter_id = ? AND l.status = 'published'`,
    )
    .bind(studentId, studentId, studentId, chapterId)
    .all<{ id: string; viewed: number; learned: number; hw_status: string | null }>();

  if (results.length === 0) return { chapterJustCompleted: false };

  // رفع اشکال امنیتی (migration 0050): «تکمیل» دیگر صرفِ دیده‌شدن نیست —
  // باید خودِ «یاد گرفتم» هم واقعاً زده شده باشد (نه فقط بازکردنِ صفحه)؛
  // نگاه کنید به کامنتِ کامل بالای [getLessonLockList].
  const allLessonsCompleted = results.every((r) => {
    const learned = r.learned === 1;
    const homeworkDone = r.hw_status === null || r.hw_status === 'submitted' || r.hw_status === 'graded';
    return learned && homeworkDone;
  });
  if (!allLessonsCompleted) return { chapterJustCompleted: false };

  // INSERT OR IGNORE + بررسیِ meta.changes: اگر دو درخواستِ هم‌زمان (مثلاً
  // دیدنِ درس و ارسالِ کار خانگی، تقریباً هم‌لحظه) هر دو به اینجا برسند، فقط
  // یکی واقعاً درج می‌کند — همان یکی امتیازِ پاداش را می‌گیرد و
  // chapterJustCompleted=true برمی‌گرداند، دیگری idempotent خاموش می‌ماند.
  const insertResult = await db
    .prepare('INSERT OR IGNORE INTO student_chapter_completions (user_id, chapter_id) VALUES (?, ?)')
    .bind(studentId, chapterId)
    .run();
  if ((insertResult.meta?.changes ?? 0) === 0) return { chapterJustCompleted: false };

  await awardPoints(db, studentId, POINTS_PER_CHAPTER_COMPLETE, 'chapter_complete', chapterId);
  return { chapterJustCompleted: true };
}

// ═══════════════════════ امتیازدهی بر اساس فعالیت (Gamification) ═══════════

// طبق سند «اقتصاد امتیاز» رقابت مکتب (نسخهٔ ۲): تماشای کامل یک درس = ۵۰XP،
// تکمیل یک فصل (که چند درس را در بر می‌گیرد) به همان نسبت بزرگ‌تر شد.
export const POINTS_PER_LESSON_VIEW = 50;
export const POINTS_PER_CHAPTER_COMPLETE = 80;

/** مشق کاغذی نمره‌گذاری‌شده توسط هوش مصنوعی (بخش «مشق کاغذی + نمره‌دهی هوشمند»). */
export const POINTS_PER_HOMEWORK_GRADED = 15;

/** درج خام یک ردیف در دفتر کل امتیازات — بدون هیچ عارضهٔ جانبی (بدون Streak).
 * [touchDailyStreak] خودش برای ثبت پاداش نقطهٔ عطف از همین تابع استفاده
 * می‌کند تا هرگز در حلقهٔ بی‌پایان با [awardPoints] نیفتد. */
async function insertPointsRow(
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

export async function awardPoints(
  db: D1Database,
  studentId: string,
  points: number,
  reason: string,
  refId: string,
): Promise<void> {
  await insertPointsRow(db, studentId, points, reason, refId);
  // هر فعالیت امتیازآور (از هر بخش برنامه) روزشمار فعالیت پیوسته را هم
  // تازه می‌کند — طبق طراحی «رقابت مکتب» (migration 0047). خودِ پاداش
  // نقطهٔ عطف با reason='streak_bonus' درج می‌شود و دوباره این تابع را
  // صدا نمی‌زند (فقط insertPointsRow) تا حلقه‌ای شکل نگیرد.
  if (reason !== 'streak_bonus') {
    await touchDailyStreak(db, studentId).catch((err) => {
      console.error('[touchDailyStreak] fail-safe — رقابت هرگز نباید فعالیت اصلی را بشکند', err);
    });
  }
}

// ═════════════════════ روزشمار فعالیت پیوسته (Daily Streak) ════════════════
// بخشی از «رقابت مکتب» (migration 0047، backend/src/routes/competition.ts).
// نقاط عطف و پاداش هرکدام — رسیدن به هرکدام یک‌بار در طول عمر حساب پاداش
// می‌دهد (milestones_awarded جلوی تکرار را می‌گیرد).
export const STREAK_MILESTONE_REWARDS: Record<number, number> = {
  3: 15,
  7: 40,
  14: 80,
  30: 150,
  60: 300,
  100: 500,
};

// طبق سند «اقتصاد امتیاز»: هر روز فعالیت = ۲۰XP؛ در هر هفتمین روز پیاپی
// (۷، ۱۴، ۲۱، …) این پاداش روزانه دو برابر می‌شود. جدا از reason خودِ
// نقاط‌عطف («streak_bonus» — یک‌بار در طول عمر حساب) تا میشن‌های «۷ روز
// پیوسته»/«۳۰ روز پیوسته» که COUNT ردیف‌های streak_bonus را می‌شمارند خراب
// نشوند؛ این یکی reason جداگانهٔ 'daily_streak_bonus' دارد.
export const STREAK_DAILY_POINTS = 20;

/** امروز به‌وقت سرور، به‌فرمت YYYY-MM-DD (سازگار با date('now') در SQLite). */
function todayIso(): string {
  return new Date().toISOString().slice(0, 10);
}

function daysBetween(a: string, b: string): number {
  const msPerDay = 24 * 60 * 60 * 1000;
  return Math.round((new Date(`${b}T00:00:00Z`).getTime() - new Date(`${a}T00:00:00Z`).getTime()) / msPerDay);
}

/**
 * هر بار که شاگرد امتیاز می‌گیرد، یک‌بار در روز صدا زده می‌شود (از داخل
 * [awardPoints]) — idempotent برای همان روز. اگر امروز اولین فعالیت بعد از
 * دقیقاً یک روز غیبت باشد، streak یک واحد بالا می‌رود؛ اگر بیش از یک روز
 * غیبت بوده، streak از ۱ شروع می‌شود؛ اگر امروز از قبل ثبت شده، کاری نمی‌کند.
 * هر روز تازه (چه شروع یک streak نو، چه ادامهٔ آن) بلافاصله پاداش روزانهٔ
 * ثابت (و دوبرابرشدهٔ هر هفتمین روز) می‌گیرد.
 */
export async function touchDailyStreak(db: D1Database, studentId: string): Promise<void> {
  const today = todayIso();

  // 🔒 رفع اشکالِ نژادی (migration 0051): گاردِ اتمیکِ «ادعای امروز» — فقط
  // درخواستی که واقعاً این ردیف را درج می‌کند (meta.changes>0) اجازه دارد
  // پاداشِ روزانه/نقطهٔ عطف را محاسبه و ثبت کند؛ هر درخواستِ هم‌زمانِ دیگر
  // برای همان (شاگرد، امروز) بی‌صدا و idempotent برمی‌گردد — نگاه کنید به
  // توضیح کامل بالای این تابع.
  const claim = await db
    .prepare('INSERT OR IGNORE INTO student_streak_daily_claims (student_id, claim_date) VALUES (?, ?)')
    .bind(studentId, today)
    .run();
  if ((claim.meta?.changes ?? 0) === 0) return;

  const row = await db
    .prepare('SELECT current_streak, longest_streak, last_active_date, milestones_awarded FROM student_streaks WHERE student_id = ?')
    .bind(studentId)
    .first<{ current_streak: number; longest_streak: number; last_active_date: string | null; milestones_awarded: string }>();

  if (!row) {
    await db
      .prepare(
        'INSERT INTO student_streaks (student_id, current_streak, longest_streak, last_active_date, milestones_awarded) VALUES (?, 1, 1, ?, ?)',
      )
      .bind(studentId, today, '[]')
      .run();
    await insertPointsRow(db, studentId, STREAK_DAILY_POINTS, 'daily_streak_bonus', today);
    return; // ۱ روز هرگز نقطهٔ عطف (milestone) نیست، ولی پاداش روزانه گرفت.
  }

  if (row.last_active_date === today) return; // امروز قبلاً ثبت شده.

  const gap = row.last_active_date ? daysBetween(row.last_active_date, today) : null;
  const newStreak = gap === 1 ? row.current_streak + 1 : 1;
  const newLongest = Math.max(row.longest_streak, newStreak);

  const dailyPoints = newStreak % 7 === 0 ? STREAK_DAILY_POINTS * 2 : STREAK_DAILY_POINTS;
  await insertPointsRow(db, studentId, dailyPoints, 'daily_streak_bonus', today);

  await db
    .prepare('UPDATE student_streaks SET current_streak = ?, longest_streak = ?, last_active_date = ? WHERE student_id = ?')
    .bind(newStreak, newLongest, today, studentId)
    .run();

  let milestones: number[] = [];
  try {
    milestones = JSON.parse(row.milestones_awarded ?? '[]');
  } catch {
    milestones = [];
  }
  const reward = STREAK_MILESTONE_REWARDS[newStreak];
  if (reward && !milestones.includes(newStreak)) {
    await insertPointsRow(db, studentId, reward, 'streak_bonus', String(newStreak));
    milestones.push(newStreak);
    await db
      .prepare('UPDATE student_streaks SET milestones_awarded = ? WHERE student_id = ?')
      .bind(JSON.stringify(milestones), studentId)
      .run();
  }
}

export type StreakStatus = { currentStreak: number; longestStreak: number; lastActiveDate: string | null };

export async function getStreakStatus(db: D1Database, studentId: string): Promise<StreakStatus> {
  try {
    const row = await db
      .prepare('SELECT current_streak, longest_streak, last_active_date FROM student_streaks WHERE student_id = ?')
      .bind(studentId)
      .first<{ current_streak: number; longest_streak: number; last_active_date: string | null }>();
    return {
      currentStreak: row?.current_streak ?? 0,
      longestStreak: row?.longest_streak ?? 0,
      lastActiveDate: row?.last_active_date ?? null,
    };
  } catch (err) {
    console.error('[getStreakStatus] fallback to zero —', err);
    return { currentStreak: 0, longestStreak: 0, lastActiveDate: null };
  }
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

const ZERO_POINTS_SUMMARY: PointsSummary = {
  totalPoints: 0,
  level: 1,
  levelTitleFa: 'نوآموز',
  nextLevelAt: 100,
  nextLevelTitleFa: 'کوشا',
  progressToNextPercent: 0,
  recent: [],
};

/**
 * محاسبهٔ امتیاز فعالیت — این تابع هرگز استثنا پرتاب نمی‌کند. اگر جدول‌های
 * امتیازدهی (مهاجرت ۰۰۱۸) هنوز روی این دیتابیس اجرا نشده باشند (یا هر خطای
 * دیگری رخ دهد)، به‌جای کرش‌دادن کل Endpoint (مثلاً جزئیات شاگرد در پنل مدیر،
 * خانهٔ شاگرد یا کارنامهٔ والد)، یک خلاصهٔ صفر امن برمی‌گرداند و فقط در لاگ
 * سرور ثبت می‌کند — یک بخش فرعی (نشان/سطح) نباید کل صفحه را از کار بیندازد.
 */
export async function getPointsSummary(db: D1Database, studentId: string): Promise<PointsSummary> {
  try {
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
  } catch (err) {
    console.error('[getPointsSummary] fallback to zero summary —', err);
    return ZERO_POINTS_SUMMARY;
  }
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

    // رفع اشکالِ ریشه‌ای: قبلاً اینجا فقط «همهٔ درس‌های فصل دیده‌شده؟» چک
    // می‌شد — یعنی صرفِ بازکردنِ صفحهٔ آخرین/تنها درسِ فصل (حتی بدون خواندنِ
    // واقعی/چت/کار خانگی) کافی بود تا فصل «تکمیل» اعلام و کلاینت بلافاصله
    // به آزمونِ فصل هدایت شود. حالا از همان معیارِ یکپارچهٔ [checkAndCompleteChapter]
    // استفاده می‌شود — که علاوه‌بر «دیده‌شدن»، «کار خانگیِ ارسال/نمره‌داده‌شده
    // (یا نبودِ کار خانگی)» را هم برای *همهٔ* درس‌های فصل شرط می‌داند؛ همان
    // معیاری که [getLessonLockList] برای قفلِ درسِ بعدی استفاده می‌کند.
    const result = await checkAndCompleteChapter(db, studentId, lesson.chapter_id);
    chapterJustCompleted = result.chapterJustCompleted;
  }

  return { found: true, firstView, chapterJustCompleted, chapterId: lesson.chapter_id };
}
