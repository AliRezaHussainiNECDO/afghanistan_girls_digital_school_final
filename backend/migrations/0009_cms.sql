-- ═══════════════════════════════════════════════════════════════════════════
-- 0009_cms.sql — مخزن تألیف محتوای مدیر (CMS، بخش ۱۴.۳ سند)
-- کتاب/درس/سؤالِ در حال تألیف با گردش‌کار draft→approved→published.
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0009_cms.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS cms_books (
  id             TEXT PRIMARY KEY,
  title          TEXT NOT NULL DEFAULT '',
  category       TEXT NOT NULL DEFAULT '',
  author         TEXT NOT NULL DEFAULT '',
  grade          TEXT NOT NULL DEFAULT '',
  chapters_count INTEGER NOT NULL DEFAULT 0,
  description    TEXT NOT NULL DEFAULT '',
  status         TEXT NOT NULL DEFAULT 'draft',
  updated_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS cms_lessons (
  id               TEXT PRIMARY KEY,
  title            TEXT NOT NULL DEFAULT '',
  chapter_title    TEXT NOT NULL DEFAULT '',
  book_title       TEXT NOT NULL DEFAULT '',
  duration_minutes INTEGER NOT NULL DEFAULT 0,
  content          TEXT NOT NULL DEFAULT '',
  status           TEXT NOT NULL DEFAULT 'draft',
  updated_at       TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS cms_questions (
  id         TEXT PRIMARY KEY,
  text       TEXT NOT NULL DEFAULT '',
  difficulty TEXT NOT NULL DEFAULT 'medium',
  subject    TEXT NOT NULL DEFAULT '',
  type       TEXT NOT NULL DEFAULT 'mcq',
  options    TEXT NOT NULL DEFAULT '[]',   -- JSON array
  answer     TEXT NOT NULL DEFAULT '',
  status     TEXT NOT NULL DEFAULT 'draft',
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);
