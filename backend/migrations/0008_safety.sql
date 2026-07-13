-- ═══════════════════════════════════════════════════════════════════════════
-- 0008_safety.sql — صف بازبینی ایمنی (بخش ۱۵.۵ سند)
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0008_safety.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- رویدادهای ایمنی ذخیره‌شده (پرچم چت، Escalation گفتگوی AI، گزارش، و
-- تصمیم‌های ثبت‌شدهٔ مدیر روی موارد at-risk).
CREATE TABLE IF NOT EXISTS safety_events (
  id             TEXT PRIMARY KEY,
  type           TEXT NOT NULL DEFAULT 'chatFlag',   -- chatFlag|aiEscalation|chatReport|atRisk
  summary        TEXT NOT NULL DEFAULT '',
  high_priority  INTEGER NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'open',        -- open|reviewed|dismissed|escalated
  student_id     TEXT,
  student_name   TEXT NOT NULL DEFAULT '',
  student_grade  TEXT NOT NULL DEFAULT '',
  source         TEXT NOT NULL DEFAULT '',
  detail         TEXT NOT NULL DEFAULT '',
  trigger_reason TEXT NOT NULL DEFAULT '',
  detected_at    TEXT NOT NULL DEFAULT (datetime('now')),
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_safety_status ON safety_events(status);
CREATE INDEX IF NOT EXISTS idx_safety_student ON safety_events(student_id, type);
