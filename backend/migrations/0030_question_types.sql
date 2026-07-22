-- ═══════════════════════════════════════════════════════════════════════════
-- 0030_question_types.sql — انواع سؤال در امتحانات رسمی (بخش ۷ سند):
--   * mcq        چهارگزینه‌ای (رفتار قبلی — پیش‌فرض تا داده‌های موجود سالم بمانند)
--   * true_false صحیح / غلط (دو گزینهٔ ثابت؛ نمره‌دهی خودکار مثل mcq)
--   * essay      تشریحی (شاگرد متن می‌نویسد؛ نمره‌دهی با هوش مصنوعی سمت سرور)
--
-- `answer_text`: پاسخ نمونه/کلید نمره‌دهی سؤال تشریحی — فقط در بخش مدیر دیده
-- می‌شود و مبنای نمره‌دهی AI است. برای سؤالات بسته NULL می‌ماند.
--
-- `essay_answers` روی exam_attempts: JSON آرایه‌ای از
--   [{questionId, answer, score(0..1), feedback}]
-- تا پاسخ تشریحی شاگرد + نمرهٔ AI برای بازبینی بعدیِ مدیر نگه داشته شود.
--
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0030_question_types.sql
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE questions ADD COLUMN q_type TEXT NOT NULL DEFAULT 'mcq';
ALTER TABLE questions ADD COLUMN answer_text TEXT;
ALTER TABLE exam_attempts ADD COLUMN essay_answers TEXT;
