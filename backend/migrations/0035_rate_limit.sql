-- 0035_rate_limit.sql — جدول سبک محدودیت نرخ برای جلوگیری از Brute-force
-- روی /auth/login و هرزنامه/حدسِ کد دعوت روی /auth/register.
--
-- رفع اشکال امنیتی: طبق بررسی آمادگی انتشار، هیچ Rate Limiting واقعی روی
-- Endpointهای احراز هویت وجود نداشت — تلاش‌های ورود ناموفق فقط در audit_logs
-- لاگ می‌شدند، ولی هیچ قفل موقتی اعمال نمی‌شد. این جدول با lib/rateLimit.ts
-- ترکیب می‌شود تا بعد از تعداد مشخصی تلاش از یک IP در یک بازهٔ زمانی، پاسخ
-- ۴۲۹ برگردد.
--
-- عمداً جدول جدا از audit_logs (که Append-only/غیرقابل‌حذف است) ساخته شده،
-- چون این جدول باید بتواند ردیف‌های قدیمی را پاک کند تا کوچک بماند.
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0035_rate_limit.sql

CREATE TABLE IF NOT EXISTS rate_limit_hits (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  rl_key TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_rate_limit_key_time ON rate_limit_hits(rl_key, created_at);
