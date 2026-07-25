-- ═══════════════════════════════════════════════════════════════════════════
-- 0044_admin_permissions.sql — مدیران زیرمجموعه (role='admin') + دسترسی‌بندی.
--
-- تا پیش از این Migration فقط یک نقش مدیریتی وجود داشت: super_admin (بدون
-- محدودیت). این Migration نقش تازهٔ `admin` را به‌عنوان «مدیر زیرمجموعه»
-- معرفی می‌کند که فقط با تخصیص صریح Super Admin به دسته‌های مشخصی از
-- عملیات مدیریتی دسترسی دارد (جدول admin_permissions).
--
-- ستون users.role از قبل TEXT آزاد است (بدون CHECK constraint) — پس مقدار
-- تازهٔ 'admin' نیازی به ALTER ندارد؛ فقط لایهٔ اپلیکیشن آن را می‌شناسد.
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0044_admin_permissions.sql
-- ═══════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS admin_permissions (
  id           TEXT PRIMARY KEY,
  user_id      TEXT NOT NULL,                  -- کاربرِ دارای role='admin'
  permission   TEXT NOT NULL,                   -- یکی از دسته‌های ثابت lib/permissions.ts
  granted_by   TEXT NOT NULL,                   -- شناسهٔ Super Admin اعطاکننده
  created_at   TEXT NOT NULL DEFAULT (datetime('now')),
  UNIQUE(user_id, permission),
  FOREIGN KEY (user_id) REFERENCES users(id),
  FOREIGN KEY (granted_by) REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_admin_permissions_user ON admin_permissions(user_id);
