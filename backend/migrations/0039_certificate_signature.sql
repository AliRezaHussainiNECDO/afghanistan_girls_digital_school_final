-- 0039_certificate_signature.sql — امضای رمزنگاری‌شدهٔ گواهی‌نامه (ECDSA
-- P-256) برای اثبات دست‌نخوردگیِ داده — طبق درخواست کاربر برای «امضای
-- دیجیتال» که با فتوشاپ قابل جعل نباشد. توضیح در exams.ts/certSigning.ts:
-- منبع حقیقت خودِ رکورد سرور است، نه فایل تصویری/PDF؛ امضا روی داده امضا
-- می‌شود و صفحهٔ عمومی تأیید اصالت آن را دوباره بررسی می‌کند.
ALTER TABLE certificates ADD COLUMN signature TEXT NOT NULL DEFAULT '';
