-- ایندکس یکتا روی serial گواهی‌نامه — برای جست‌وجوی سریع در صفحهٔ عمومی
-- تأیید اصالت (GET /certificates/verify/:serial) که پشت QR روی خودِ سند است.
CREATE UNIQUE INDEX IF NOT EXISTS idx_certs_serial ON certificates(serial);
