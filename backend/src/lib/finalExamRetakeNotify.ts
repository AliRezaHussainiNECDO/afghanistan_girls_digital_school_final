/**
 * lib/finalExamRetakeNotify.ts — پوش نوتیفیکیشن واقعی «فرصت تلاش دوبارهٔ
 * امتحان فاینل باز شد» (migration 0043).
 *
 * زمینه: واجدشرایط‌بودنِ تلاش دوم (بعد از ۱۵ روز از تلاش ناکام) در
 * routes/finalExams.ts به‌صورت Lazy محاسبه می‌شود — یعنی خودِ باز شدنِ فرصت
 * به هیچ عمل فعالی نیاز ندارد. اما اگر شاگرد خودش سراغ صفحهٔ امتحان فاینل
 * نرود، هیچ‌کس به او یادآوری نمی‌کند. این فایل دقیقاً همان شکاف را با یک
 * Cron روزانه (نگاه کنید به index.ts::scheduled + wrangler.toml [triggers])
 * پر می‌کند: هر روز چک می‌کند کدام تلاش‌های ناکام امروز به ۱۵ روزشان
 * رسیده‌اند و هنوز اطلاع داده نشده‌اند، برای هرکدام Push واقعی می‌فرستد و
 * ستون retake_notified را ۱ می‌کند تا فردا دوباره تکراری ارسال نشود.
 *
 * Fail-safe کامل (هماهنگ با بقیهٔ پروژه): هر ردیف جداگانه try/catch دارد —
 * خطای Push برای یک شاگرد بقیه را متوقف نمی‌کند؛ نبود پیکربندی FCM باعث
 * کرش نمی‌شود (خودِ sendPushToUser در نبود FCM_PROJECT_ID بی‌صدا برمی‌گردد).
 */
import { sendPushToUser } from './push';

type RetakeNotifyEnv = {
  DB: D1Database;
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
};

type DueRow = { id: string; user_id: string; final_exam_id: string; title: string };

export async function notifyFinalExamRetakesDue(env: RetakeNotifyEnv): Promise<{ notified: number }> {
  const { results } = await env.DB.prepare(
    `SELECT a.id, a.user_id, a.final_exam_id, e.title
     FROM final_exam_attempts a
     JOIN final_exams e ON e.id = a.final_exam_id
     WHERE a.passed = 0
       AND a.retake_notified = 0
       AND a.retake_available_at IS NOT NULL
       AND a.retake_available_at <= datetime('now')
       AND a.attempt_number = (
         SELECT MAX(a2.attempt_number) FROM final_exam_attempts a2
         WHERE a2.user_id = a.user_id AND a2.final_exam_id = a.final_exam_id
       )`,
  ).all<DueRow>();

  let notified = 0;
  for (const row of results) {
    try {
      await sendPushToUser(
        env,
        row.user_id,
        'امتحان فاینل — فرصت تلاش دوباره 🌸',
        `فرصت تلاش دوبارهٔ «${row.title}» باز شد. هر وقت آماده بودید امتحان بدهید.`,
        { kind: 'final_exam_retake', relatedId: row.final_exam_id },
      );
    } catch (err) {
      console.error('[finalExamRetakeNotify] push failed for', row.id, err);
    } finally {
      // چه Push موفق شود چه نه (مثلاً کاربر دستگاه ثبت‌شده ندارد)، این ردیف
      // «پردازش‌شده» علامت می‌خورد تا Cron فردا دوباره برایش تلاش نکند —
      // دقیقاً مثل بقیهٔ اعلان‌های یک‌بارهٔ پروژه.
      await env.DB.prepare('UPDATE final_exam_attempts SET retake_notified = 1 WHERE id = ?')
        .bind(row.id)
        .run()
        .catch(() => {});
      notified++;
    }
  }
  return { notified };
}
