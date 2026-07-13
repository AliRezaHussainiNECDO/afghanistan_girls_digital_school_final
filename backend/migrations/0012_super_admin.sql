-- ═══════════════════════════════════════════════════════════════════════════
-- 0012_super_admin.sql — ساخت حساب اصلی مدیر کل (Super Admin).
-- رمز عبور فقط به‌صورت هش PBKDF2 ذخیره می‌شود (هرگز plaintext — بخش ۱۷.۱ سند).
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0012_super_admin.sql
-- ═══════════════════════════════════════════════════════════════════════════

INSERT INTO users (id, email, password_hash, first_name, last_name, role, status, preferred_language)
VALUES (
  'u_super_admin_ali',
  'alireza.necdo@gmail.com',
  'pbkdf2$100000$gRFpx4Qck+NEG0QM4wJFqQ==$ioEV0gbvcnXRPdy+CDQ/48OThoLwduxIhWIKOrc5fZk=',
  'Ali Reza',
  'Hussaini',
  'super_admin',
  'active',
  'fa'
)
ON CONFLICT(email) DO UPDATE SET
  password_hash = excluded.password_hash,
  role          = 'super_admin',
  status        = 'active',
  updated_at    = datetime('now');
