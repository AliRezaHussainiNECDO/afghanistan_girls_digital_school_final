-- ═══════════════════════════════════════════════════════════════════════════
-- 0037_exam_attempts_unique.sql — تضمین «یک‌بار دادن» در سطح دیتابیس:
--
-- قبلاً «هر امتحان فقط یک‌بار» فقط با یک SELECT قبل از INSERT در کد بررسی
-- می‌شد (routes/exams.ts) — دو درخواست هم‌زمان (تپ دوگانه/تلاش مجدد شبکه)
-- می‌توانستند هر دو از آن عبور کنند و دو تلاش برای یک امتحان ثبت شود.
--
-- ۱) پاک‌سازی احتیاطی: قبل از این migration، سیستم امتحانات اجازهٔ چند
--    تلاش/تلاش مجدد می‌داد، پس ممکن است رکوردهای قدیمیِ تکراری برای یک
--    (exam_id, user_id) از قبل وجود داشته باشند. برای هر گروه تکراری، فقط
--    بهترین نمره نگه داشته می‌شود (و در تساوی نمره، قدیمی‌ترین تلاش) — بقیه
--    حذف می‌شوند تا ایندکس یکتای زیر بدون خطا ساخته شود.
-- ۲) ایندکس یکتا: از این پس، حتی در صورت رقابت هم‌زمان دو درخواست، خودِ
--    دیتابیس دومی را رد می‌کند (کد routes/exams.ts این خطا را می‌گیرد و
--    همان پیام «قبلاً داده‌اید» را برمی‌گرداند).
-- ═══════════════════════════════════════════════════════════════════════════

DELETE FROM exam_attempts
WHERE EXISTS (
  SELECT 1 FROM exam_attempts b
  WHERE b.exam_id = exam_attempts.exam_id
    AND b.user_id = exam_attempts.user_id
    AND (
      b.score_percent > exam_attempts.score_percent
      OR (b.score_percent = exam_attempts.score_percent AND b.submitted_at < exam_attempts.submitted_at)
      OR (b.score_percent = exam_attempts.score_percent AND b.submitted_at = exam_attempts.submitted_at AND b.id < exam_attempts.id)
    )
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_exam_attempts_unique_exam_user ON exam_attempts(exam_id, user_id);
