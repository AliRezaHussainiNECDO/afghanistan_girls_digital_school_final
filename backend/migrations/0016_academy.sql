-- ═══════════════════════════════════════════════════════════════════════════
-- 0016_academy.sql — «آکادمی»: کتابخانه، بانک سؤال و پاسخ‌ها روی سرور تا بین
-- همهٔ کاربران و دستگاه‌ها مشترک و ماندگار باشد (به‌جای حافظهٔ موقت).
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0016_academy.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS academy_books (
  id             TEXT PRIMARY KEY,
  title          TEXT NOT NULL,
  subject        TEXT NOT NULL DEFAULT '',
  grade_id       INTEGER NOT NULL DEFAULT 0,
  category       TEXT NOT NULL DEFAULT '',
  author         TEXT NOT NULL DEFAULT '',
  description    TEXT NOT NULL DEFAULT '',
  language       TEXT NOT NULL DEFAULT 'دری',
  pdf_file_name  TEXT NOT NULL DEFAULT '',
  file_size_mb   REAL NOT NULL DEFAULT 0,
  page_count     INTEGER NOT NULL DEFAULT 0,
  cover_index    INTEGER NOT NULL DEFAULT 0,
  include_in_rag INTEGER NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'draft',        -- draft|published
  uploaded_at    TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at     TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_academy_books_status ON academy_books(status);

CREATE TABLE IF NOT EXISTS academy_questions (
  id            TEXT PRIMARY KEY,
  subject       TEXT NOT NULL DEFAULT '',
  grade_id      INTEGER NOT NULL DEFAULT 0,
  chapter       TEXT NOT NULL DEFAULT '',
  kind          TEXT NOT NULL DEFAULT 'mcq',           -- mcq|trueFalse|essay
  text          TEXT NOT NULL DEFAULT '',
  options_json  TEXT NOT NULL DEFAULT '[]',
  correct_index INTEGER NOT NULL DEFAULT 0,
  correct_bool  INTEGER NOT NULL DEFAULT 1,
  model_answer  TEXT NOT NULL DEFAULT '',
  points        INTEGER NOT NULL DEFAULT 1,
  status        TEXT NOT NULL DEFAULT 'draft',
  ai_generated  INTEGER NOT NULL DEFAULT 0,
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_academy_questions_subject ON academy_questions(subject, grade_id, status);

CREATE TABLE IF NOT EXISTS academy_submissions (
  id            TEXT PRIMARY KEY,
  student_id    TEXT NOT NULL,
  student_name  TEXT NOT NULL DEFAULT '',
  grade_id      INTEGER NOT NULL DEFAULT 0,
  subject       TEXT NOT NULL DEFAULT '',
  submitted_at  TEXT NOT NULL DEFAULT (datetime('now')),
  answers_json  TEXT NOT NULL DEFAULT '[]',
  score_percent REAL NOT NULL DEFAULT 0,
  earned_points REAL NOT NULL DEFAULT 0,
  total_points  REAL NOT NULL DEFAULT 0,
  ai_assisted   INTEGER NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_academy_submissions_student ON academy_submissions(student_id);

-- ── محتوای نمونهٔ اولیه (کتاب‌ها و بانک سؤال) تا آکادمی خالی نباشد ──────────
INSERT OR IGNORE INTO academy_books (id, title, subject, grade_id, category, author, description, page_count, cover_index, include_in_rag, status, uploaded_at, updated_at) VALUES
  ('lb1','ریاضی صنف نهم','ریاضی',9,'کتاب درسی رسمی','وزارت معارف','کتاب درسی رسمی ریاضیات صنف نهم شامل جبر، هندسه و آمار مقدماتی.',168,0,1,'published','2026-06-10','2026-06-20'),
  ('lb2','فزیک صنف نهم','فزیک',9,'کتاب درسی رسمی','وزارت معارف','مبانی مکانیک، حرکت و نیرو مطابق نصاب رسمی.',142,2,1,'published','2026-06-12','2026-06-18'),
  ('lb3','داستان‌های کوتاه دری','ادبیات دری',0,'داستان','گروه محتوای مکتب','مجموعه‌ای از داستان‌های کوتاه برای تقویت مهارت خواندن.',54,4,0,'draft','2026-07-01','2026-07-01');

INSERT OR IGNORE INTO academy_questions (id, subject, grade_id, chapter, kind, text, options_json, correct_index, correct_bool, model_answer, points, status, created_at) VALUES
  ('bq1','ریاضی',9,'فصل ۳ — معادلات','mcq','مجموع زوایای داخلی یک مثلث چند درجه است؟','["۹۰","۱۸۰","۲۷۰","۳۶۰"]',1,1,'',1,'published','2026-06-25'),
  ('bq2','ریاضی',9,'فصل ۳ — معادلات','trueFalse','معادلهٔ درجهٔ دوم همیشه دو ریشهٔ حقیقی دارد.','[]',0,0,'',1,'published','2026-06-26'),
  ('bq3','فزیک',9,'فصل ۲ — حرکت','essay','قانون دوم نیوتن را توضیح دهید و یک مثال از زندگی روزمره بزنید.','[]',0,1,'نیرو برابر است با جرم ضرب در شتاب (F=ma). مثال: هل دادن یک چرخ‌دستی.',5,'published','2026-06-28'),
  ('bq7a','ریاضی',7,'فصل ۱ — اعداد','mcq','حاصل ۷ × ۸ چند است؟','["۴۹","۵۶","۶۳","۶۴"]',1,1,'',1,'published','2026-07-01'),
  ('bq7b','ریاضی',7,'فصل ۱ — اعداد','trueFalse','عدد ۱۷ یک عدد اول است.','[]',0,1,'',1,'published','2026-07-01'),
  ('bq7c','ریاضی',7,'فصل ۲ — کسرها','mcq','حاصل ۱/۲ + ۱/۴ چند است؟','["۱/۶","۲/۶","۳/۴","۱/۸"]',2,1,'',1,'published','2026-07-01');
