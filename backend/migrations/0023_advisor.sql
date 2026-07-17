-- ═══════════════════════════════════════════════════════════════════════════
-- 0023_advisor.sql — گفتگوهای «مشاور هوشمند» (رفع اشکال حیاتی امنیتی)
--
-- قبلاً این گفتگوها فقط در حافظهٔ محلی گوشیِ شاگرد (AdvisorStore) نگه
-- داشته می‌شد و هرگز به سرور نمی‌رسید؛ یعنی پیام‌های پرچم‌شده (نشانهٔ
-- خودآزاری/آزار/ازدواج اجباری و...) هرگز به مدیر واقعی مکتب نمی‌رسید، با
-- اینکه در UI به شاگرد گفته می‌شد «مدیریت مکتب بازبینی می‌کند». این جدول
-- منبع واحد و واقعی این گفتگوها را روی سرور فراهم می‌کند.
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0023_advisor.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS advisor_messages (
  id           TEXT PRIMARY KEY,
  student_id   TEXT NOT NULL,
  student_name TEXT NOT NULL DEFAULT '',
  role         TEXT NOT NULL,               -- student|advisor
  text         TEXT NOT NULL DEFAULT '',
  topic        TEXT NOT NULL DEFAULT 'عمومی',
  flagged      INTEGER NOT NULL DEFAULT 0,  -- ۱ = نیازمند توجه فوری مدیر
  created_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_advisor_student ON advisor_messages(student_id, created_at);
CREATE INDEX IF NOT EXISTS idx_advisor_flagged ON advisor_messages(flagged);
