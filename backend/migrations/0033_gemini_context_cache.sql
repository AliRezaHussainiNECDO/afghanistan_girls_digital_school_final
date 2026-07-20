-- 0033_gemini_context_cache.sql — پشتیبانی Context Caching گوگل برای چت معلم هوشمند.
--
-- هدف (کاهش شدید هزینهٔ توکن ورودی): متن کامل درس که در System Prompt چت
-- «تمرکز مطلق بر درس» قرار می‌گیرد، یک بار در Context Cache گوگل ذخیره و نامش
-- اینجا نگه داشته می‌شود؛ چت‌های بعدیِ همان درس به‌جای ارسال دوبارهٔ کل متن،
-- فقط نام کش را می‌فرستند. کاملاً Fail-safe: اگر کش نباشد/بسازد نشود، همان
-- مسیر قبلی (systemInstruction کامل) استفاده می‌شود — هیچ رفتاری نمی‌شکند.
--
-- 🚨 خط قرمز: هیچ تغییری در جدول‌ها/منطق امتیازدهی، فیصدی پیشرفت، «یاد
-- گرفتم» و کار خانگی — فقط دو ستون افزودنی روی lessons.

ALTER TABLE lessons ADD COLUMN gemini_cache_name TEXT;
ALTER TABLE lessons ADD COLUMN cache_expires_at TEXT;
