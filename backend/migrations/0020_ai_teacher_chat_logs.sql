-- ═══════════════════════════════════════════════════════════════════════════
-- 0020_ai_teacher_chat_logs.sql — لاگ سبک هر پیام واقعی معلم هوشمند، تا پنل
-- «مدیریت معلم هوشمند» بتواند آمار حقیقی (نه ساختگی، نه خالی) نشان بدهد:
-- تعداد پیام‌ها، شاگردان فعال، و پرکاربردترین مضمون‌ها.
--
-- رفع اشکال (بعدتر): در ابتدا فقط پیام‌هایی که از موتور ابری Worker
-- (`/ai-teacher/chat`) پاسخ می‌گرفتند لاگ می‌شدند — یعنی وقتی AI_PROVIDER_KEY
-- تنظیم نشده بود (حالت پیش‌فرض/رایگان این پروژه) و همه‌چیز از موتور محلی
-- پاسخ می‌گرفت، این جدول برای همیشه خالی می‌ماند و پنل مدیر می‌گفت «معلم
-- هوشمند وصل نیست». اکنون کلاینت بعد از **هر** پاسخ (ابری یا محلی) از طریق
-- `POST /ai-teacher/log-message` اینجا می‌نویسد — مستقل از موتور.
--
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0020_ai_teacher_chat_logs.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ai_teacher_chat_logs (
  id          TEXT PRIMARY KEY,
  student_id  TEXT NOT NULL,
  subject_id  TEXT NOT NULL,
  created_at  TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ai_chat_logs_subject ON ai_teacher_chat_logs(subject_id);
CREATE INDEX IF NOT EXISTS idx_ai_chat_logs_student ON ai_teacher_chat_logs(student_id);
CREATE INDEX IF NOT EXISTS idx_ai_chat_logs_created ON ai_teacher_chat_logs(created_at);
