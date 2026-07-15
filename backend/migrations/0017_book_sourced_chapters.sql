-- ═══════════════════════════════════════════════════════════════════════════
-- 0017_book_sourced_chapters.sql — پیوند فصل‌های نصاب با کتاب مبدأ (آپلود مدیر)
-- + قفل‌گذاری ترتیبی فصل‌ها (فصل بعدی بعد از تکمیل فصل جاری باز می‌شود).
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0017_book_sourced_chapters.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- کدام کتابِ کتابخانهٔ نصاب (curriculum_library_books) این فصل را تولید کرده
-- (برای امکان جایگزینی/به‌روزرسانی فصل‌ها هنگام آپلود مجدد همان کتاب).
ALTER TABLE chapters ADD COLUMN source_book_id TEXT;

-- شمارهٔ صفحهٔ شروع فصل در PDF مبدأ (برای نمایش/دیباگ شناسایی هوشمند عناوین).
ALTER TABLE chapters ADD COLUMN source_page_start INTEGER;

CREATE INDEX IF NOT EXISTS idx_chapters_source_book ON chapters(source_book_id);

-- تکمیل فصل توسط دانش‌آموز: اولین باری که همهٔ درس‌های یک فصل «دیده‌شده» علامت
-- می‌خورند، یک ردیف اینجا درج می‌شود. این هم پایهٔ قفل‌گشایی فصل بعدی است و هم
-- جلوگیری از اهدای دوبارهٔ امتیاز پاداش تکمیل فصل (بخش 0018).
CREATE TABLE IF NOT EXISTS student_chapter_completions (
  user_id       TEXT NOT NULL,
  chapter_id    TEXT NOT NULL,
  completed_at  TEXT NOT NULL DEFAULT (datetime('now')),
  PRIMARY KEY (user_id, chapter_id)
);
CREATE INDEX IF NOT EXISTS idx_chapter_completions_user ON student_chapter_completions(user_id);
