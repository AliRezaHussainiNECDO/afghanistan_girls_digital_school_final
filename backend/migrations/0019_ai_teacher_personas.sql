-- ═══════════════════════════════════════════════════════════════════════════
-- 0019_ai_teacher_personas.sql — شخصیت معلم هوشمند هر مضمون (بخش ۵.۲/۱۷.۳).
-- قبلاً این تنظیمات فقط در SharedPreferences هر دستگاه ذخیره می‌شد (نه روی
-- سرور)؛ یعنی تنظیمات مدیر روی یک دستگاه، روی بقیهٔ دستگاه‌ها یا برای معلم
-- هوشمندی که واقعاً به شاگردان پاسخ می‌دهد (سمت سرور) دیده نمی‌شد. این جدول
-- آن را روی سرور مشترک می‌کند.
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0019_ai_teacher_personas.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ai_teacher_personas (
  subject_id          TEXT PRIMARY KEY,
  subject_name_fa     TEXT NOT NULL,
  persona_description TEXT NOT NULL,
  prompt_version      INTEGER NOT NULL DEFAULT 1,
  updated_at          TEXT NOT NULL DEFAULT (datetime('now')),
  updated_by_admin_id TEXT
);
