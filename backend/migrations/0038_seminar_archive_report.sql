-- 0038_seminar_archive_report.sql
--
-- رفع اشکال «آرشیف سمینار»: قبلاً سمینارهای پایان‌یافته برای همیشه در همان
-- وضعیت (published/ended) می‌ماندند و هیچ‌وقت به‌طور خودکار به «آرشیف»
-- منتقل نمی‌شدند، و هیچ گزارشی از برگزاری آن‌ها ذخیره نمی‌شد. این migration
-- دو ستون اضافه می‌کند تا سرور بتواند (در `routes/seminars.ts`) به‌محض
-- گذشتن زمان سمینار، آن را خودکار «archived» کند و یک گزارش خلاصهٔ
-- تولیدشده با هوش مصنوعی برایش ذخیره کند.

ALTER TABLE seminars ADD COLUMN ai_report_fa TEXT NOT NULL DEFAULT '';
ALTER TABLE seminars ADD COLUMN archived_at TEXT;
