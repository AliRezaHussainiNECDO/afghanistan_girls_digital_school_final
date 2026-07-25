-- ═══════════════════════════════════════════════════════════════════════════
-- 0041_chapter_quizzes_and_final_exams.sql
--
-- دو قابلیت جدید طبق درخواست صاحب پروژه (بدون تغییر در جدول‌های `exams`/
-- `questions`/`exam_attempts` قدیمی — آن سیستم دست‌نخورده باقی می‌ماند و
-- برای امتحانات تک‌مضمونهٔ روزانه/ماهانه/کارخانگی همچنان استفاده می‌شود):
--
-- ۱) «آزمون فصل» (chapter_quizzes/questions/attempts): وقتی شاگرد تمام
--    درس‌های یک فصل را می‌بیند، سیستم به‌صورت خودکار (هوش مصنوعی، حداقل ۱۲
--    سؤال ترکیبی) یک آزمون برای همان فصل می‌سازد (یک‌بار، مشترک بین همهٔ
--    شاگردان همان فصل — نه AI جداگانه برای هر شاگرد). قفل فصل بعدی از این
--    پس به «آیا این آزمون را داده‌ام» بستگی دارد، نه صرفاً «آیا همهٔ
--    درس‌ها را دیده‌ام» (پیاده‌سازی در lib/progress.ts).
--
-- ۲) «امتحان فاینل» چندمضمونه (final_exams/questions/attempts): برخلاف
--    `exams.type='final'` قدیمی (که تک‌مضمونه بود)، یک امتحان فاینل واحد
--    برای کل صنف می‌سازد که حداقل ۳ سؤال از هر مضمون و در مجموع نزدیک به
--    ۳۰ سؤال دارد. اگر شاگرد قبول نشد، ۱۵ روز بعد دوباره مجاز به تلاش است
--    (attempt_number) — بدون نیاز به هیچ Cron/Scheduled Worker: واجد شرایط
--    بودنِ تلاش تازه در لحظهٔ درخواست شاگرد محاسبه می‌شود (retake_available_at).
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0041_chapter_quizzes_and_final_exams.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- ─────────────────────────────── آزمون فصل ──────────────────────────────────

CREATE TABLE IF NOT EXISTS chapter_quizzes (
  id              TEXT PRIMARY KEY,
  chapter_id      TEXT NOT NULL UNIQUE,        -- هر فصل حداکثر یک آزمون (بازتولید نمی‌شود)
  status          TEXT NOT NULL DEFAULT 'draft', -- draft|published
  pass_threshold  REAL NOT NULL DEFAULT 40,     -- آسان‌گیرانه — هدف مسئولیت‌پذیری، نه سخت‌گیری
  question_count  INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (chapter_id) REFERENCES chapters(id)
);

CREATE TABLE IF NOT EXISTS chapter_quiz_questions (
  id            TEXT PRIMARY KEY,
  quiz_id       TEXT NOT NULL,
  q_type        TEXT NOT NULL DEFAULT 'mcq',   -- mcq|true_false|essay (هماهنگ با migration 0030)
  text          TEXT NOT NULL,
  options       TEXT NOT NULL DEFAULT '[]',
  correct_index INTEGER NOT NULL DEFAULT -1,
  answer_text   TEXT,                          -- کلید نمره‌دهی AI برای essay
  order_index   INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (quiz_id) REFERENCES chapter_quizzes(id)
);
CREATE INDEX IF NOT EXISTS idx_chapter_quiz_questions_quiz ON chapter_quiz_questions(quiz_id);

CREATE TABLE IF NOT EXISTS chapter_quiz_attempts (
  id             TEXT PRIMARY KEY,
  quiz_id        TEXT NOT NULL,
  chapter_id     TEXT NOT NULL,   -- تکرار عمدی برای Join سریع در گزارش پرونده شاگرد
  user_id        TEXT NOT NULL,
  score_percent  REAL NOT NULL DEFAULT 0,
  correct_count  INTEGER NOT NULL DEFAULT 0,
  total_count    INTEGER NOT NULL DEFAULT 0,
  passed         INTEGER NOT NULL DEFAULT 0, -- 0/1 — فقط اطلاعاتی؛ باز شدن فصل بعدی به همین «ارسال شده» بستگی دارد نه به passed
  essay_answers  TEXT,   -- JSON [{questionId, answer, score, feedback}]
  answers_json   TEXT,   -- JSON {questionId: correctIndex} پاسخ‌های بسته
  submitted_at   TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (quiz_id) REFERENCES chapter_quizzes(id),
  UNIQUE (quiz_id, user_id)   -- یک‌بار ارسال — دقیقاً مثل امتحانات رسمی (0037)
);
CREATE INDEX IF NOT EXISTS idx_chapter_quiz_attempts_user ON chapter_quiz_attempts(user_id, chapter_id);

-- ─────────────────────────── امتحان فاینل چندمضمونه ─────────────────────────

CREATE TABLE IF NOT EXISTS final_exams (
  id              TEXT PRIMARY KEY,
  grade_number    INTEGER NOT NULL,
  academic_year   TEXT NOT NULL DEFAULT '',
  title           TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'draft', -- draft|published|closed
  pass_threshold  REAL NOT NULL DEFAULT 80,       -- هماهنگ با PROMOTION_EXAM_PASS_PERCENT سرور/kExamPassPercent کلاینت
  question_count  INTEGER NOT NULL DEFAULT 0,
  created_at      TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_final_exams_grade ON final_exams(grade_number, status);

CREATE TABLE IF NOT EXISTS final_exam_questions (
  id            TEXT PRIMARY KEY,
  final_exam_id TEXT NOT NULL,
  subject_id    TEXT NOT NULL,  -- هر سؤال به یک مضمون مشخص تعلق دارد (حداقل ۳ سؤال از هر مضمون)
  q_type        TEXT NOT NULL DEFAULT 'mcq',
  text          TEXT NOT NULL,
  options       TEXT NOT NULL DEFAULT '[]',
  correct_index INTEGER NOT NULL DEFAULT -1,
  answer_text   TEXT,
  order_index   INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (final_exam_id) REFERENCES final_exams(id),
  FOREIGN KEY (subject_id) REFERENCES subjects(id)
);
CREATE INDEX IF NOT EXISTS idx_final_exam_questions_exam ON final_exam_questions(final_exam_id);

CREATE TABLE IF NOT EXISTS final_exam_attempts (
  id                    TEXT PRIMARY KEY,
  final_exam_id         TEXT NOT NULL,
  user_id               TEXT NOT NULL,
  attempt_number        INTEGER NOT NULL DEFAULT 1,
  score_percent         REAL NOT NULL DEFAULT 0,
  correct_count         INTEGER NOT NULL DEFAULT 0,
  total_count           INTEGER NOT NULL DEFAULT 0,
  passed                INTEGER NOT NULL DEFAULT 0,
  essay_answers         TEXT,
  answers_json          TEXT,
  submitted_at          TEXT NOT NULL DEFAULT (datetime('now')),
  -- فقط وقتی passed=0: چه زمانی دوباره مجاز به تلاش است (submitted_at + ۱۵ روز).
  -- NULL یعنی یا قبول شده یا هنوز تلاشی ثبت نشده.
  retake_available_at   TEXT,
  FOREIGN KEY (final_exam_id) REFERENCES final_exams(id),
  UNIQUE (final_exam_id, user_id, attempt_number)
);
CREATE INDEX IF NOT EXISTS idx_final_exam_attempts_user ON final_exam_attempts(user_id, final_exam_id);
