-- ═══════════════════════════════════════════════════════════════════════════
-- 0028_push_tokens.sql — توکن‌های دستگاه برای Push Notification واقعی (FCM).
-- هر ردیف یعنی «این کاربر روی این گوشی/دستگاه مشخص نصب دارد». یک کاربر
-- می‌تواند چند دستگاه داشته باشد؛ اما یک توکن مشخص همیشه فقط به یک کاربر
-- وصل است (`fcm_token` یکتا است، نه ترکیب کاربر+توکن) — اگر همان گوشی بعداً
-- زیر حساب کاربری دیگری وارد شد (logout/login)، ثبت تازه مالکیت قبلی را
-- جایگزین می‌کند (`ON CONFLICT(fcm_token) DO UPDATE` در routes/devices.ts).
--
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0028_push_tokens.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS device_push_tokens (
  id          TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL,
  fcm_token   TEXT NOT NULL,
  platform    TEXT NOT NULL DEFAULT 'android',  -- android|ios|web
  created_at  TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_push_tokens_token ON device_push_tokens(fcm_token);
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON device_push_tokens(user_id);
