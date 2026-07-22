-- ═══════════════════════════════════════════════════════════════════════════
-- 0032_presence.sql — حضور زندهٔ کاربران (داشبورد زندهٔ مدیر):
-- هر درخواستِ دارای توکن معتبر، `last_seen_at` کاربر را در پس‌زمینه
-- (waitUntil در src/index.ts) تازه می‌کند. «آنلاین» یعنی فعالیت در ۲ دقیقهٔ
-- اخیر — مبنای شمارنده‌ها و فهرست «همین حالا آنلاین» در
-- GET /admin/dashboard/live (routes/admin.ts).
--
-- اجرا:
--   wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0032_presence.sql
-- ═══════════════════════════════════════════════════════════════════════════

ALTER TABLE users ADD COLUMN last_seen_at TEXT;
CREATE INDEX IF NOT EXISTS idx_users_last_seen ON users(last_seen_at);
