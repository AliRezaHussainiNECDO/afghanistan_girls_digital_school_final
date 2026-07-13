-- ═══════════════════════════════════════════════════════════════════════════
-- 0005_engagement.sql — اعلان‌ها (بخش ۱۳/۱۷.۶). حاضری از فعالیت واقعی
-- (بازدید درس + تلاش امتحان) محاسبه می‌شود و جدول جدا لازم ندارد (بخش ۹.۱).
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0005_engagement.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS notifications (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  title_fa   TEXT NOT NULL,
  body_fa    TEXT NOT NULL DEFAULT '',
  priority   TEXT NOT NULL DEFAULT 'medium',  -- low|medium|high
  kind       TEXT NOT NULL DEFAULT 'general',  -- book|exam|grade|seminar|safety|general
  read_at    TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_notifs_user ON notifications(user_id, created_at);
