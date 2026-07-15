-- ═══════════════════════════════════════════════════════════════════════════
-- 0021_lesson_embeddings.sql — بردار معنایی هر درس، برای «بازیابی معنایی»
-- (RAG واقعی) معلم هوشمند به‌جای تطابق سادهٔ کلمه‌ای. هر ردیف نمایندهٔ یک
-- درس در جدول `lessons` است (طبق معماری تازه: هر فصل چند درس کوتاه دارد).
--
-- D1/SQLite بردار بومی ندارد؛ چون حجم داده (نصاب یک مکتب) کوچک است، بردارها
-- به‌صورت JSON ذخیره می‌شوند و شباهت کسینوسی در خودِ Worker محاسبه می‌شود —
-- بدون نیاز به سرویس Vector جداگانه.
--
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0021_lesson_embeddings.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS lesson_embeddings (
  lesson_id     TEXT PRIMARY KEY,
  chapter_id    TEXT NOT NULL,
  subject_id    TEXT NOT NULL,
  grade_number  INTEGER NOT NULL,
  model         TEXT NOT NULL,
  embedding     TEXT NOT NULL,  -- JSON array of floats
  updated_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_lesson_embeddings_scope ON lesson_embeddings(subject_id, grade_number);
