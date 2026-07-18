-- 0026_audit_logs.sql — لاگ بازبینی سراسری و غیرقابل‌تغییر (بخش ۲۰.۳ سند / اصلاحیه v2.4).
--
-- اصل Auditability (بخش ۱.۲): هر اقدام حساس مدیر، ورود/خروج، تغییر وضعیت
-- کاربر، صدور/ابطال کد دعوت، انتشار/حذف محتوا، تصمیم پیوند والد-فرزند، و
-- «هر فراخوانی معلم هوشمند شامل Prompt کامل ارسالی» (بخش ۵.۶) اینجا ثبت می‌شود.
--
-- Immutable (Append-only): چون D1 کاربر/مجوز سطح دیتابیس ندارد (برخلاف
-- PostgreSQL که سند v2.3 فرض کرده بود REVOKE UPDATE/DELETE می‌کنیم)،
-- تغییرناپذیری با Trigger های خود SQLite تضمین می‌شود: هر UPDATE یا DELETE
-- روی این جدول — حتی از طرف کد خود Worker یا کنسول D1 — با خطا رد می‌شود.
--
-- اجرا:
--   npx wrangler d1 execute afghan_girls_school_db --remote --file=./migrations/0026_audit_logs.sql

CREATE TABLE IF NOT EXISTS audit_logs (
  id TEXT PRIMARY KEY,
  actor_id TEXT,                                -- NULL = سیستم/ناشناس (مثلاً تلاش ورود ناموفق)
  actor_role TEXT,                              -- نقش لحظهٔ اقدام (super_admin/student/…)
  action_type TEXT NOT NULL,                    -- 'ai_invocation'|'login_success'|'login_failed'|'user_register'|
                                                -- 'user_status_change'|'invite_code_issue'|'invite_code_revoke'|
                                                -- 'password_reset_link'|'content_status_change'|'content_delete'|
                                                -- 'parent_link_request'|'parent_link_decision'|'safety_resolve'|
                                                -- 'curriculum_wipe'|'logout'|…
  target_table TEXT,                            -- جدول هدف (users/invite_codes/cms_lessons/…)
  target_id TEXT,                               -- شناسهٔ رکورد هدف
  reason TEXT,                                  -- دلیل (مثلاً دلیل تعلیق)
  before_value TEXT,                            -- JSON وضعیت قبل (در صورت وجود)
  after_value TEXT,                             -- JSON وضعیت بعد (در صورت وجود)
  detail TEXT,                                  -- JSON آزاد — برای ai_invocation: Prompt کامل (messages)
  ip_address TEXT,                              -- CF-Connecting-IP
  priority TEXT NOT NULL DEFAULT 'normal',      -- 'normal' | 'high' (بخش ۱۰.۴.۳ — Escalation ایمنی)
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_audit_created ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON audit_logs(actor_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action_type, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_priority ON audit_logs(priority) WHERE priority = 'high';

-- ── تضمین Append-only در سطح دیتابیس ──────────────────────────────────────
CREATE TRIGGER IF NOT EXISTS audit_logs_no_update
BEFORE UPDATE ON audit_logs
BEGIN
  SELECT RAISE(ABORT, 'audit_logs is append-only (immutable)');
END;

CREATE TRIGGER IF NOT EXISTS audit_logs_no_delete
BEFORE DELETE ON audit_logs
BEGIN
  SELECT RAISE(ABORT, 'audit_logs is append-only (immutable)');
END;
