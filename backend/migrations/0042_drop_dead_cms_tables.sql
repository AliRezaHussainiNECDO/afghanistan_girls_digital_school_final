-- 0042_drop_dead_cms_tables.sql
--
-- پاک‌سازی کد مرده: `cms_books`، `cms_lessons`، `cms_questions` (از
-- migrations/0009_cms.sql) پشتوانهٔ روتر backend/src/routes/cms.ts بودند که
-- اکنون کاملاً حذف شده. هیچ‌کدام از این سه جدول هرگز از کلاینت واقعی
-- (اپ فلاتر) نوشته/خوانده نمی‌شدند:
--   - `cms_books`/`cms_questions`: تب‌های «کتاب‌ها»/«سؤالات» در پنل مدیر
--     از ابتدا مستقیم به روتر `academy` (کتابخانه/بانک سؤال واقعیِ آکادمی —
--     همان که «تمرین مضامین» شاگردان از آن تغذیه می‌شود) وصل بودند، نه به
--     این جدول‌ها.
--   - `cms_lessons`: `CmsRemoteDataSource` (فلاتر) قبلاً اصلاح شد تا به‌جای
--     این جدول، مستقیم به `/admin/curriculum/lessons` (نصاب واقعیِ
--     `lessons`/`chapters`) بنویسد.
-- پس این سه جدول بی‌اثر بودند و هیچ دادهٔ واقعیِ در-حال-استفاده‌ای از دست
-- نمی‌رود.
DROP TABLE IF EXISTS cms_books;
DROP TABLE IF EXISTS cms_lessons;
DROP TABLE IF EXISTS cms_questions;
