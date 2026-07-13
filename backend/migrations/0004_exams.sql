-- ═══════════════════════════════════════════════════════════════════════════
-- 0004_exams.sql — امتحانات، پاسخ‌ها، نمرات و گواهی‌نامه (بخش ۷/۸/۱۷.۴)
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0004_exams.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS exams (
  id               TEXT PRIMARY KEY,
  subject_id       TEXT NOT NULL,
  grade_number     INTEGER NOT NULL,
  type             TEXT NOT NULL DEFAULT 'daily_quiz', -- daily_quiz|homework|monthly|final
  title            TEXT NOT NULL,
  duration_minutes INTEGER NOT NULL DEFAULT 10,
  status           TEXT NOT NULL DEFAULT 'published',  -- draft|admin_approved|published|closed
  created_at       TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_exams_gs ON exams(grade_number, subject_id);

CREATE TABLE IF NOT EXISTS questions (
  id            TEXT PRIMARY KEY,
  exam_id       TEXT NOT NULL,
  text          TEXT NOT NULL,
  options       TEXT NOT NULL,                 -- JSON array از گزینه‌ها
  correct_index INTEGER NOT NULL,              -- هرگز به کلاینت فرستاده نمی‌شود (بخش ۷.۲)
  order_index   INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (exam_id) REFERENCES exams(id)
);
CREATE INDEX IF NOT EXISTS idx_questions_exam ON questions(exam_id);

-- تلاش‌های امتحان + نمرهٔ محاسبه‌شدهٔ سرور (State Machine بخش ۷.۴).
CREATE TABLE IF NOT EXISTS exam_attempts (
  id             TEXT PRIMARY KEY,
  exam_id        TEXT NOT NULL,
  user_id        TEXT NOT NULL,
  score_percent  REAL NOT NULL DEFAULT 0,
  correct_count  INTEGER NOT NULL DEFAULT 0,
  total_count    INTEGER NOT NULL DEFAULT 0,
  submitted_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_attempts_user ON exam_attempts(user_id, exam_id);

-- گواهی‌نامه‌ها (بخش ۸.۲/۱۷.۴).
CREATE TABLE IF NOT EXISTS certificates (
  id           TEXT PRIMARY KEY,
  serial       TEXT NOT NULL,
  student_id   TEXT NOT NULL,
  student_name TEXT NOT NULL DEFAULT '',
  grade        INTEGER NOT NULL,
  year_label   TEXT NOT NULL DEFAULT '',
  average      REAL NOT NULL DEFAULT 0,
  honor        TEXT NOT NULL DEFAULT '',
  issued_by    TEXT NOT NULL DEFAULT 'مدیریت مکتب',
  issued_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_certs_student ON certificates(student_id);

-- ─────────────────────────── داده‌های نمونه (Seed) ───────────────────────────
INSERT OR IGNORE INTO exams (id, subject_id, grade_number, type, title, duration_minutes) VALUES
  ('ex-g7-math-q1',    'math',    7, 'daily_quiz', 'کوییز روزانهٔ ریاضی — اعداد صحیح', 8),
  ('ex-g7-physics-m1', 'physics', 7, 'monthly',    'امتحان ماهانهٔ فزیک — اندازه‌گیری', 45);

INSERT OR IGNORE INTO questions (id, exam_id, text, options, correct_index, order_index) VALUES
  ('q-m1','ex-g7-math-q1','حاصل ۳ + (−۵) چند است؟','["۲","−۲","۸","−۸"]',1,1),
  ('q-m2','ex-g7-math-q1','حاصل (−۴) × (−۲) چند است؟','["−۸","−۶","۸","۶"]',2,2),
  ('q-m3','ex-g7-math-q1','کدام عدد صحیح منفی است؟','["۰","۵","−۳","۷"]',2,3),
  ('q-m4','ex-g7-math-q1','قرینهٔ عدد ۶ کدام است؟','["۶","−۶","۰","۱"]',1,4),
  ('q-p1','ex-g7-physics-m1','یکای اصلی طول در SI چیست؟','["گرم","متر","ثانیه","لیتر"]',1,1),
  ('q-p2','ex-g7-physics-m1','کدام کمیت اصلی است؟','["سرعت","نیرو","زمان","کار"]',2,2),
  ('q-p3','ex-g7-physics-m1','یکای زمان در SI چیست؟','["دقیقه","ساعت","ثانیه","روز"]',2,3);
