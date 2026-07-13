-- ═══════════════════════════════════════════════════════════════════════════
-- 0007_parent_links.sql — پیوند امن والد-فرزند (بخش ۲.۴ و ۱۳ب سند)
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0007_parent_links.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- کد دعوت والد که خودِ دانش‌آموز تولید می‌کند (توکن اختصاصی — بخش ۲.۴).
-- هر دانش‌آموز فقط یک کد فعال دارد؛ تولید کد جدید کد قبلی را جایگزین می‌کند.
CREATE TABLE IF NOT EXISTS guardian_codes (
  student_user_id TEXT PRIMARY KEY,
  code            TEXT NOT NULL,
  expires_at      TEXT NOT NULL,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_guardian_codes_code ON guardian_codes(code);

-- پیوند والد ↔ فرزند (معادل parent_student_links بخش ۱۷.۱).
CREATE TABLE IF NOT EXISTS parent_student_links (
  id              TEXT PRIMARY KEY,
  parent_user_id  TEXT NOT NULL,
  student_user_id TEXT NOT NULL,
  parent_name     TEXT NOT NULL DEFAULT '',
  status          TEXT NOT NULL DEFAULT 'pending_student_approval', -- pending_student_approval|approved|rejected
  approved_at     TEXT,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE (parent_user_id, student_user_id)
);
CREATE INDEX IF NOT EXISTS idx_psl_parent  ON parent_student_links(parent_user_id, status);
CREATE INDEX IF NOT EXISTS idx_psl_student ON parent_student_links(student_user_id, status);
