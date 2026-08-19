-- 0051_streak_daily_claim.sql — رفع اشکالِ نژادی (race condition) در
-- `touchDailyStreak` (backend/src/lib/progress.ts).
--
-- ریشهٔ اشکال: `touchDailyStreak` از الگوی «بخوان، بعد تصمیم بگیر، بعد
-- بنویس» استفاده می‌کند (SELECT ردیفِ streak → اگر last_active_date !=
-- امروز → INSERT پاداشِ روزانه + احتمالاً پاداشِ نقطهٔ عطف → UPDATE ردیف).
-- این تابع از داخل [awardPoints] صدا زده می‌شود که خودش از چند نقطهٔ مختلفِ
-- برنامه (تماشای درس، تکمیل فصل، نمره‌دهیِ کار خانگی، قبولی در آزمونِ فصل +
-- پاداشِ زودهنگام) — گاهی تقریباً هم‌زمان — فراخوانی می‌شود. اگر دو
-- درخواستِ هم‌زمان هر دو SELECT را قبل از این‌که هرکدام UPDATE را تمام کند
-- انجام دهند، هر دو `last_active_date !== today` را می‌بینند و هر دو
-- پاداشِ روزانه (و در روزِ نقطهٔ عطف، پاداشِ آن را هم) را دوباره ثبت
-- می‌کنند — امتیازِ رایگانِ تکراری.
--
-- راه‌حل: دقیقاً همان الگویی که [checkAndCompleteChapter] برای رفع مشکلِ
-- مشابه استفاده می‌کند — یک جدولِ کوچکِ «ادعای امروز» با کلید ترکیبیِ
-- (student_id, claim_date). `INSERT OR IGNORE` + بررسیِ `meta.changes` یک
-- گاردِ اتمیک است: فقط اولین درخواستِ هم‌زمان واقعاً درج می‌کند (و همان یکی
-- منطقِ محاسبهٔ streak/پاداش را ادامه می‌دهد)؛ بقیه بی‌صدا و idempotent
-- برمی‌گردند.
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0051_streak_daily_claim.sql

CREATE TABLE IF NOT EXISTS student_streak_daily_claims (
  student_id TEXT NOT NULL,
  claim_date TEXT NOT NULL,
  PRIMARY KEY (student_id, claim_date)
);
