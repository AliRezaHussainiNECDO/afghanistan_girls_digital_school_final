-- ═══════════════════════════════════════════════════════════════════════════
-- 0002_auth_system.sql — جداول احراز هویت (users + invite_codes + refresh_tokens)
-- مطابق بخش ۱۷.۱ سند SPEC v2.4. اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0002_auth_system.sql
-- (برای تست محلی: --local به‌جای --remote)
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS users (
  id                   TEXT PRIMARY KEY,
  email                TEXT NOT NULL UNIQUE,
  password_hash        TEXT NOT NULL,                     -- pbkdf2$iter$salt$hash (هرگز plaintext)
  first_name           TEXT NOT NULL DEFAULT '',
  last_name            TEXT NOT NULL DEFAULT '',
  phone                TEXT,
  role                 TEXT NOT NULL DEFAULT 'student',   -- student|parent|seminar_instructor|super_admin
  status               TEXT NOT NULL DEFAULT 'active',    -- active|suspended|pending_verification|deleted
  current_grade        INTEGER,                           -- فقط دانش‌آموز (۷..۱۲)
  province             TEXT,
  date_of_birth        TEXT,
  preferred_language   TEXT NOT NULL DEFAULT 'fa',        -- fa|ps|en
  awaiting_parent_link INTEGER NOT NULL DEFAULT 0,        -- فقط والد (بخش ۳.۶)
  specialty            TEXT,                              -- فقط استاد سمینار
  bio                  TEXT,
  created_at           TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at           TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_role  ON users(role);

CREATE TABLE IF NOT EXISTS invite_codes (
  id                 TEXT PRIMARY KEY,
  code               TEXT NOT NULL UNIQUE,
  type               TEXT NOT NULL DEFAULT 'student',     -- student|instructor
  batch_label        TEXT,                                -- نام سازمان/ولایت توزیع‌کننده (بخش ۳ب.۳)
  status             TEXT NOT NULL DEFAULT 'unused',      -- unused|used|revoked|expired
  used_by_user_id    TEXT,
  used_at            TEXT,
  issued_by_admin_id TEXT,
  expires_at         TEXT,                                -- ISO8601؛ NULL = بدون انقضا
  created_at         TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_invite_codes_code   ON invite_codes(code);
CREATE INDEX IF NOT EXISTS idx_invite_codes_status ON invite_codes(status);

-- Refresh Tokenها با Rotation و امکان ابطال (بخش ۳.۳ سند).
CREATE TABLE IF NOT EXISTS refresh_tokens (
  id         TEXT PRIMARY KEY,                            -- jti داخل JWT رفرش
  user_id    TEXT NOT NULL,
  revoked    INTEGER NOT NULL DEFAULT 0,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_refresh_user ON refresh_tokens(user_id);

-- ─────────────── کدهای دعوت نمونه برای تست فوری (بخش ۳ب.۳) ───────────────
INSERT OR IGNORE INTO invite_codes (id, code, type, batch_label, status) VALUES
  ('ic-seed-1', 'DEMO-STU-001', 'student',    'بچ نمایشی دانش‌آموزان', 'unused'),
  ('ic-seed-2', 'DEMO-STU-002', 'student',    'بچ نمایشی دانش‌آموزان', 'unused'),
  ('ic-seed-3', 'DEMO-STU-003', 'student',    'بچ نمایشی دانش‌آموزان', 'unused'),
  ('ic-seed-4', 'TCH-DEMO01',   'instructor', 'بچ نمایشی استادان',     'unused');
