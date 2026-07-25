-- migration 0043 — پوش نوتیفیکیشن واقعیِ «تلاش دوم امتحان فاینل باز شد».
--
-- زمینه: طبق migrations/0041، وقتی شاگرد در امتحان فاینل ناکام شود (کمتر از
-- ۸۰٪)، ستون retake_available_at (اکنون + ۱۵ روز) روی همان تلاش ثبت می‌شود و
-- واجدشرایط‌بودنِ تلاش تازه فقط وقتی شاگرد خودش دوباره صفحهٔ امتحان فاینل را
-- باز کند محاسبه می‌شد (Lazy — بدون Cron). این یعنی اگر شاگرد خودش سراغ
-- امتحان نرود، هیچ‌کس به او یادآوری نمی‌کرد که فرصت دوباره باز شده.
--
-- این ستون تازه اجازه می‌دهد یک Worker زمان‌بندی‌شدهٔ روزانه (نگاه کنید به
-- lib/finalExamRetakeNotify.ts + index.ts::scheduled) دقیقاً یک‌بار برای هر
-- تلاشِ ناکام، وقتی retake_available_at فرا رسید، پوش واقعی بفرستد — بدون
-- ارسال تکراری در اجراهای بعدی همان Cron.
ALTER TABLE final_exam_attempts ADD COLUMN retake_notified INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_final_exam_attempts_retake_due
  ON final_exam_attempts(passed, retake_notified, retake_available_at);
