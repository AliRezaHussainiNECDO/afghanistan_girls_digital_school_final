-- ═══════════════════════════════════════════════════════════════════════════
-- 0022_ai_teacher_answer_logs.sql — لاگ ساختاریافتهٔ درست/غلط بودن هر پاسخ
-- شاگرد به سؤال معلم هوشمند — پایهٔ «حلقهٔ یادگیری تطبیقی»: هم برای تطبیق
-- سطح سختی در همان گفتگو، هم برای آمار دقت در پنل مدیر.
--
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0022_ai_teacher_answer_logs.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ai_teacher_answer_logs (
  id            TEXT PRIMARY KEY,
  student_id    TEXT NOT NULL,
  subject_id    TEXT NOT NULL,
  grade_number  INTEGER NOT NULL,
  was_correct   INTEGER NOT NULL, -- 0/1
  created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_ai_answer_logs_student ON ai_teacher_answer_logs(student_id);
CREATE INDEX IF NOT EXISTS idx_ai_answer_logs_subject ON ai_teacher_answer_logs(subject_id);
CREATE INDEX IF NOT EXISTS idx_ai_answer_logs_created ON ai_teacher_answer_logs(created_at);
