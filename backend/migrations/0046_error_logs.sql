-- ═══════════════════════════════════════════════════════════════════════════
-- 0046_error_logs.sql — «گزارش خطاهای برنامه» (بک‌اند + اپ فلاتر یک‌جا).
--
-- چرا لازم است؟ تا امروز وقتی بخشی از اپ یا سرور کار نمی‌کرد، تنها راه
-- تشخیص، توضیح دستیِ کاربر یا کنسول `wrangler tail` بود. این جدول محل واحدِ
-- ذخیرهٔ هر خطای اجرایی است — چه در Cloudflare Worker (لایهٔ `app.onError` در
-- src/index.ts + `captureError` در lib/errorLog.ts) و چه در اپ فلاتر (قلاب
-- شده به `AppErrorHandler.record` که همین حالا هر سه مسیر خطای مدیریت‌نشده
-- را می‌گیرد: FlutterError/PlatformDispatcher/ZoneGuard — نگاه کن lib/main.dart) —
-- با کد خطا، دسته‌بندی، شدت، پیام و Stack trace کامل، و تاریخ/روز/ساعت دقیق،
-- تا از پنل مدیر (routes/errorLogs.ts + features/admin/error_logs) قابل
-- مرور و «کپی برای هوش مصنوعی» باشد.
--
-- منطق تشخیص کد خطا/شدت/fingerprint در lib/errorLog.ts است، نه اینجا.
--
-- اجرا:
--   npx wrangler d1 migrations apply afghan_girls_school_db --remote
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS error_logs (
  id                    TEXT PRIMARY KEY,

  -- شناسایی
  error_code            TEXT NOT NULL,           -- مثل AUTH-401, DB-1062, API-000
  category              TEXT NOT NULL,           -- AUTH|DATABASE|API|UI|VALIDATION|NETWORK|UNKNOWN
  severity              TEXT NOT NULL DEFAULT 'medium', -- low|medium|high|critical

  -- چه اتفاقی افتاد
  title                 TEXT NOT NULL,
  message               TEXT NOT NULL,
  stack_trace           TEXT,
  context_json          TEXT,                    -- JSON آزاد: بدنهٔ درخواست/پاسخ، breadcrumb و...

  -- کجا اتفاق افتاد
  source                TEXT NOT NULL,           -- flutter_app | cloudflare_worker
  screen_or_endpoint    TEXT,                    -- مثل '/api/v1/admin/login' یا 'AdminLoginScreen'
  http_method           TEXT,
  http_status           INTEGER,

  -- دستگاه/محیط (فقط برای source='flutter_app')
  platform              TEXT,                    -- android|ios|web|windows|macos|linux
  app_version           TEXT,
  os_version            TEXT,
  device_model          TEXT,
  locale                TEXT,

  -- کاربر آسیب‌دیده
  user_id               TEXT,
  user_role             TEXT,

  -- زمان‌بندی — با دقت میلی‌ثانیه (مثل audit_logs، رجوع کن lib/audit.ts) تا
  -- در صفحه‌بندی/مرتب‌سازی رشته‌ای هرگز دو رویداد هم‌زمان قاطی نشوند.
  occurred_at           TEXT NOT NULL,           -- 'YYYY-MM-DD HH:MM:SS.sss'
  occurred_date         TEXT NOT NULL,           -- YYYY-MM-DD (فیلتر سریع)
  occurred_day_of_week  TEXT NOT NULL,           -- مثلاً «یکشنبه»
  occurred_time         TEXT NOT NULL,           -- HH:MM:SS

  -- پیگیری/گردش‌کار
  status                TEXT NOT NULL DEFAULT 'new', -- new|investigating|resolved|ignored
  resolution_notes      TEXT,
  resolved_at           TEXT,
  resolved_by           TEXT,                    -- شناسهٔ مدیر حل‌کننده

  -- ضدتکرار: اگر همان خطا دوباره رخ دهد، فقط occurrence_count بالا می‌رود
  -- (به‌جای هزاران ردیف تکراری) — نگاه کن errorLogsHandlers در routes/errorLogs.ts
  occurrence_count      INTEGER NOT NULL DEFAULT 1,
  fingerprint           TEXT,

  created_at            TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at            TEXT NOT NULL DEFAULT (datetime('now')),

  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX IF NOT EXISTS idx_error_logs_created_at  ON error_logs (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_error_logs_status      ON error_logs (status);
CREATE INDEX IF NOT EXISTS idx_error_logs_severity    ON error_logs (severity);
CREATE INDEX IF NOT EXISTS idx_error_logs_category    ON error_logs (category);
CREATE INDEX IF NOT EXISTS idx_error_logs_fingerprint ON error_logs (fingerprint);
