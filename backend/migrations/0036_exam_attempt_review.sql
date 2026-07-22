-- 0036_exam_attempt_review.sql — ذخیرهٔ پاسخ‌های خام هر تلاش امتحان تا شاگرد
-- (و والد/مدیر) بتوانند بعداً سؤال‌به‌سؤال مرور کنند که کدام پاسخ درست/غلط
-- بوده — طبق درخواست کاربر برای صفحهٔ «نتایج امتحانات» شاگرد.
--
-- قبلاً `exam_attempts` فقط نمرهٔ تجمیعی (score_percent/correct_count/
-- total_count) را نگه می‌داشت، نه اینکه شاگرد به هر سؤال چه پاسخی داده بود؛
-- پس هیچ راهی برای ساخت صفحهٔ «مرور پاسخ‌ها» وجود نداشت.
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0036_exam_attempt_review.sql

ALTER TABLE exam_attempts ADD COLUMN answers_json TEXT;
