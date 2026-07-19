-- ═══════════════════════════════════════════════════════════════════════════
-- 0027_student_homework.sql — «مشق کاغذی + نمره‌دهی هوشمند»: شاگرد مشق را روی
-- کاغذ می‌نویسد، عکس می‌گیرد، هوش مصنوعی (Vision) آن را OCR/نمره‌گذاری می‌کند،
-- و شاگرد می‌تواند دربارهٔ نمره‌اش با معلم هوشمند گفتگو کند.
--
-- طراحی «صنف‌محور و آینده‌نگر»: هر مشق به `class_level` (همان قرارداد
-- grade_number در 0003_curriculum.sql، اعداد ۷ تا ۱۲) وصل است، نه به یک صنف
-- ثابت — یعنی وقتی شاگرد به صنف بعدی ارتقا می‌یابد (`promoteIfEligible` در
-- lib/progress.ts)، فهرست مشق‌های او خودکار با صنف تازه‌اش هماهنگ می‌ماند،
-- بدون هیچ کد اضافه یا مهاجرت جدید.
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0027_student_homework.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS student_homeworks (
  id                 TEXT PRIMARY KEY,
  student_id         TEXT NOT NULL,
  subject_id         TEXT NOT NULL,               -- FK منطقی → subjects.id
  chapter_id         TEXT NOT NULL DEFAULT '',     -- FK منطقی → chapters.id (اختیاری)
  lesson_id          TEXT NOT NULL DEFAULT '',     -- FK منطقی → lessons.id (اختیاری)
  class_level        INTEGER NOT NULL,             -- grade_number در زمان محول‌شدن مشق (۷..۱۲)
  question_text      TEXT NOT NULL DEFAULT '',
  hint_text          TEXT NOT NULL DEFAULT '',
  status             TEXT NOT NULL DEFAULT 'pending',  -- pending|submitted|graded
  student_image_url  TEXT NOT NULL DEFAULT '',     -- کلید R2 عکس دست‌خط شاگرد
  extracted_text      TEXT NOT NULL DEFAULT '',     -- نتیجهٔ OCR/Vision
  ai_score           INTEGER,                       -- ۰..۱۰۰ (NULL تا وقتی نمره داده نشده)
  ai_feedback        TEXT NOT NULL DEFAULT '',      -- بازخورد دری/پشتو
  created_at         TEXT NOT NULL DEFAULT (datetime('now')),
  submitted_at       TEXT,
  graded_at          TEXT
);
CREATE INDEX IF NOT EXISTS idx_homeworks_student ON student_homeworks(student_id, class_level);
CREATE INDEX IF NOT EXISTS idx_homeworks_student_status ON student_homeworks(student_id, status);
CREATE INDEX IF NOT EXISTS idx_homeworks_subject ON student_homeworks(subject_id, class_level);

-- تاریخچهٔ گفت‌وگوی شاگرد ↔ معلم هوشمند دربارهٔ یک مشق مشخص (پیگیری نمره).
CREATE TABLE IF NOT EXISTS homework_replies (
  id            TEXT PRIMARY KEY,
  homework_id   TEXT NOT NULL,
  sender        TEXT NOT NULL DEFAULT 'student',  -- student|ai
  message_text  TEXT NOT NULL DEFAULT '',
  created_at    TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (homework_id) REFERENCES student_homeworks(id)
);
CREATE INDEX IF NOT EXISTS idx_homework_replies_hw ON homework_replies(homework_id, created_at);

-- ── داده‌های نمونهٔ اولیه (Seed) — تا فهرست مشق‌های صنف ۷/۸ خالی نباشد ───────
INSERT OR IGNORE INTO student_homeworks
  (id, student_id, subject_id, chapter_id, lesson_id, class_level, question_text, hint_text, status)
VALUES
  ('hw_seed_1', 'seed-student', 'math', 'ch-g7-math-2', 'ls-g7-math-2-2', 7,
   'سه کسر ۱/۲ + ۱/۳ + ۱/۶ را جمع کنید و مراحل حل را روی کاغذ بنویسید.',
   'ابتدا مخرج مشترک هر سه کسر را پیدا کنید.', 'pending'),
  ('hw_seed_2', 'seed-student', 'physics', 'ch-g7-physics-2', 'ls-g7-physics-2-1', 7,
   'اگر یک موتر در ۴ ثانیه از ۰ به ۲۰ متر بر ثانیه برسد، شتاب آن را حساب کنید.',
   'شتاب = تغییر سرعت ÷ زمان.', 'pending');
