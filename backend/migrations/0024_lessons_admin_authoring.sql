-- ═══════════════════════════════════════════════════════════════════════════
-- 0024_lessons_admin_authoring.sql — رفع اشکال: تب «مدیریت محتوا > دروس»
--
-- قبلاً این تب فقط به جدول جداگانه و بی‌اثر cms_lessons می‌نوشت که هیچ
-- شاگردی هرگز نمی‌دید (نصاب واقعی از جدول lessons/chapters می‌آید — بخش
-- ۰۰۰۳). این مهاجرت یک ستون updated_at به lessons واقعی اضافه می‌کند تا
-- فهرست مدیریتی جدید (routes/curriculum.ts → /admin/curriculum/lessons*)
-- بتواند بر اساس آخرین ویرایش مرتب کند.
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0024_lessons_admin_authoring.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- مقدار پیش‌فرض باید ثابت باشد (SQLite/D1 عبارت غیرثابت را در ADD COLUMN
-- همیشه نمی‌پذیرد)؛ سپس مقدار واقعی را برای ردیف‌های موجود پر می‌کنیم.
ALTER TABLE lessons ADD COLUMN updated_at TEXT NOT NULL DEFAULT '1970-01-01T00:00:00Z';
UPDATE lessons SET updated_at = datetime('now') WHERE updated_at = '1970-01-01T00:00:00Z';
