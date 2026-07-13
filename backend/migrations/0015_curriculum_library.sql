-- ═══════════════════════════════════════════════════════════════════════════
-- 0015_curriculum_library.sql — کتابخانهٔ نصاب (متن استخراج‌شدهٔ کتاب‌های
-- درسی) به‌عنوان پایگاه دانش معلم هوشمند، روی سرور تا بین همه مشترک باشد.
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0015_curriculum_library.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS curriculum_library_books (
  id             TEXT PRIMARY KEY,
  subject_id     TEXT NOT NULL,
  title          TEXT NOT NULL,
  page_count     INTEGER NOT NULL DEFAULT 0,
  grade_id       INTEGER NOT NULL DEFAULT 0,     -- 7..12 ؛ 0 = بدون صنف مشخص
  extracted_text TEXT NOT NULL DEFAULT '',       -- متن کامل برای RAG معلم هوشمند
  uploaded_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_curriculum_library_subject ON curriculum_library_books(subject_id);
CREATE INDEX IF NOT EXISTS idx_curriculum_library_grade   ON curriculum_library_books(grade_id);
