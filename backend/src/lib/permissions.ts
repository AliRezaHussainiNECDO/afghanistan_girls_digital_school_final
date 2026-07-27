/**
 * lib/permissions.ts — دسته‌بندی دسترسی‌های مدیران زیرمجموعه («بخش مدیریت
 * مدیران» — Migration 0044).
 *
 * معماری دسترسی مدیریتی:
 *   • role='super_admin'  → دسترسی کامل و بدون قید (همیشه).
 *   • role='admin'        → «مدیر زیرمجموعه» — فقط دسته‌های دسترسیِ صریحاً
 *     تخصیص‌داده‌شده در جدول admin_permissions را دارد. Super Admin این
 *     دسته‌ها را از پنل «مدیریت مدیران» تخصیص/لغو می‌کند.
 *
 * دسته‌بندی عمداً کلی (نه به‌ازای هر Endpoint) نگه داشته شده تا برای مدیر
 * قابل فهم و مدیریت باشد — هر دسته چند Endpoint هم‌موضوع را می‌پوشاند
 * (برای نگاشت دقیق هر دسته به مسیرها → routes/admin.ts).
 */

export const ADMIN_PERMISSIONS = [
  'manage_users', // کاربران، شاگردان، والدین (بخش ۱۵.۲) — لیست/تعلیق/ارتقا/کاهش صنف/بازیابی رمز
  'manage_content', // نصاب/کتابخانهٔ نصاب/معلم هوشمند (بخش نصاب هوشمند)
  'manage_exams', // مدیریت آزمون‌ها و امتحانات نهایی
  'manage_seminars', // مدیریت سمینارها
  'manage_safety_chat', // نظارت بر چت + صف ایمنی (بخش ۱۵.۵)
  'manage_invite_codes', // کدهای دعوت (بخش ۳ب.۳)
  'view_reports_audit', // گزارش خلاصهٔ پلتفرم + لاگ بازبینی (فقط‌خواندنی)
  'manage_notifications', // اعلان‌ها
  'manage_error_logs', // گزارش خطاهای برنامه (Migration 0046) — مرور/تغییر وضعیت/حذف رکوردهای error_logs
] as const;

export type AdminPermission = (typeof ADMIN_PERMISSIONS)[number];

export function isValidPermission(v: string): v is AdminPermission {
  return (ADMIN_PERMISSIONS as readonly string[]).includes(v);
}

/** آیا کاربر (role='admin') دسترسی مشخصی را دارد؟ */
export async function hasAdminPermission(
  db: D1Database,
  userId: string,
  permission: AdminPermission,
): Promise<boolean> {
  const row = await db
    .prepare('SELECT 1 FROM admin_permissions WHERE user_id = ? AND permission = ? LIMIT 1')
    .bind(userId, permission)
    .first();
  return !!row;
}

/** فهرست کامل دسترسی‌های یک مدیر زیرمجموعه. */
export async function getAdminPermissions(db: D1Database, userId: string): Promise<AdminPermission[]> {
  const { results } = await db
    .prepare('SELECT permission FROM admin_permissions WHERE user_id = ?')
    .bind(userId)
    .all<{ permission: string }>();
  return results.map((r) => r.permission).filter(isValidPermission);
}
