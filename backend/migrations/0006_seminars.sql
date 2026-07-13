-- ═══════════════════════════════════════════════════════════════════════════
-- 0006_seminars.sql — سمینارهای زنده (بخش ۱۲/۱۷.۷ سند)
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0006_seminars.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS seminars (
  id               TEXT PRIMARY KEY,
  title            TEXT NOT NULL,
  description      TEXT NOT NULL DEFAULT '',
  instructor_id    TEXT NOT NULL DEFAULT '',
  instructor_name  TEXT NOT NULL DEFAULT '',
  scheduled_start  TEXT NOT NULL,                 -- ISO8601
  duration_minutes INTEGER NOT NULL DEFAULT 45,
  status           TEXT NOT NULL DEFAULT 'published', -- نام enum فلاتر: draft|published|registrationClosed|live|ended|archived
  capacity         INTEGER,                       -- NULL = بدون محدودیت
  audience         TEXT NOT NULL DEFAULT 'students', -- students|parents
  created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_seminars_audience ON seminars(audience, status);

CREATE TABLE IF NOT EXISTS seminar_registrations (
  seminar_id    TEXT NOT NULL,
  user_id       TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'registered', -- registered|waitlisted|attended|no_show
  registered_at TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (seminar_id, user_id)
);

-- ─────────────────────────── سمینارهای نمونه (Seed) ──────────────────────────
INSERT OR IGNORE INTO seminars (id, title, description, instructor_id, instructor_name, scheduled_start, duration_minutes, status, capacity, audience) VALUES
  ('sem-seed-1','مهارت‌های مطالعهٔ مؤثر','تکنیک‌های علمی برای مطالعهٔ عمیق، مدیریت زمان و آمادگی امتحان.','u-instructor-demo','استاد رحیمی', strftime('%Y-%m-%dT%H:%M:%SZ','now','+1 day'), 60, 'published', 100, 'students'),
  ('sem-seed-2','آمادگی برای امتحان کانکور','مرور استراتژی‌های پاسخ‌دهی، مدیریت استرس و برنامه‌ریزی هفتگی.','u-instructor-demo','استاد رحیمی', strftime('%Y-%m-%dT%H:%M:%SZ','now','+3 day'), 60, 'published', 50, 'students'),
  ('sem-seed-3','نقش والدین در آموزش دیجیتال','چگونه از فرزند خود در مسیر یادگیری آنلاین حمایت کنیم؟','u-instructor-demo','استاد رحیمی', strftime('%Y-%m-%dT%H:%M:%SZ','now','+2 day'), 45, 'published', 60, 'parents');
