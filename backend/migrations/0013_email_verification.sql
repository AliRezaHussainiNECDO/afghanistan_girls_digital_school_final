-- ═══════════════════════════════════════════════════════════════════════════
-- 0013_email_verification.sql — تأیید ایمیل، بازیابی پسورد، و عکس پروفایل.
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0013_email_verification.sql
-- ═══════════════════════════════════════════════════════════════════════════

-- ستون‌های جدید کاربر: وضعیت تأیید ایمیل + آدرس عکس پروفایل.
ALTER TABLE users ADD COLUMN email_verified INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN avatar_url TEXT;

-- کاربران موجود (پیش از این نسخه) به‌صورت خودکار تأییدشده علامت می‌خورند تا
-- هیچ حساب فعلی دچار محدودیت نشود.
UPDATE users SET email_verified = 1;

-- توکن‌های ایمیل: هم لینک تأیید ایمیل (type='verify') و هم کد ۶ رقمی
-- بازیابی پسورد (type='reset'). فقط هشِ توکن/کد ذخیره می‌شود (SHA-256)
-- تا نشت دیتابیس منجر به سوءاستفاده نشود.
CREATE TABLE IF NOT EXISTS email_tokens (
  id         TEXT PRIMARY KEY,
  user_id    TEXT NOT NULL,
  type       TEXT NOT NULL,                            -- verify|reset
  token_hash TEXT NOT NULL,                            -- SHA-256(token) به Base64Url
  expires_at TEXT NOT NULL,                            -- ISO8601
  used       INTEGER NOT NULL DEFAULT 0,
  attempts   INTEGER NOT NULL DEFAULT 0,               -- شمارش تلاش‌های ناموفق (فقط reset)
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (user_id) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_email_tokens_user ON email_tokens(user_id, type);
