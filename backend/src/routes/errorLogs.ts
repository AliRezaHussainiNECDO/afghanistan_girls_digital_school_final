/**
 * routes/errorLogs.ts — «گزارش خطاهای برنامه» (Migration 0046 / lib/errorLog.ts).
 *
 * Endpointها (زیر `/api/v1`):
 *   POST   /errors                       — ثبت خطا (بدون نیاز به Bearer؛ اپ حتی
 *                                           برای کاربر مهمان/گزارش‌نشده هم باید
 *                                           بتواند کرش را بفرستد)
 *   GET    /admin/error-logs             — فهرست + فیلتر (status/severity/category/
 *                                           from/to/q) + صفحه‌بندی — نیاز به مجوز
 *                                           'manage_error_logs'
 *   GET    /admin/error-logs/:id         — جزئیات کامل (پیام، Stack trace، Context)
 *   PATCH  /admin/error-logs/:id         — تغییر وضعیت (investigating/resolved/ignored)
 *   DELETE /admin/error-logs/:id
 *
 * چرا این Endpointِ عمومی خطر ندارد؟ فقط INSERT در جدول error_logs انجام
 * می‌شود (بدون خواندن هیچ دادهٔ دیگری)، و طبق lib/errorLog.ts هیچ استثنایی
 * از اینجا بیرون نمی‌رود.
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { hasAdminPermission, type AdminPermission } from '../lib/permissions';
import { captureError, normalizeCategory } from '../lib/errorLog';

type Bindings = { DB: D1Database; JWT_SECRET: string };

const errorLogs = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

/** همان الگوی routes/admin.ts — تکرار عمدی (هر روتر مستقل است، رجوع کن routes/devices.ts). */
async function requireAdmin(c: any, permission?: AdminPermission): Promise<string | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  const role = p['role'];
  const sub = p['sub'] as string;
  if (role === 'super_admin') return sub;
  if (role === 'admin') {
    if (!permission) return sub;
    if (await hasAdminPermission(c.env.DB, sub, permission)) return sub;
  }
  return null;
}

// ─────────────────────── ثبت خطا (عمومی — اپ فلاتر) ─────────────────────────
errorLogs.post('/errors', async (c) => {
  const body = await c.req.json<Record<string, unknown>>().catch(() => null);
  if (!body || typeof body.message !== 'string' || !body.message.trim()) {
    return c.json(fail('BAD_REQUEST', 'فیلد message الزامی است', 'The "message" field is required'), 400);
  }

  // اگر کاربر واردشده بود، شناسه‌اش را (حتی بدون نیاز به مجوز خاص) ضمیمه کن.
  let userId: string | null = null;
  let userRole: string | null = null;
  const authHeader = c.req.header('Authorization');
  if (authHeader?.startsWith('Bearer ')) {
    try {
      const p = await verifyBearer(authHeader, c.env.JWT_SECRET);
      userId = (p?.['sub'] as string | undefined) ?? null;
      userRole = (p?.['role'] as string | undefined) ?? null;
    } catch {
      /* توکن نامعتبر/منقضی — گزارش خطا را رد نمی‌کنیم، فقط بدون شناسهٔ کاربر ثبت می‌شود */
    }
  }

  await captureError(c.env.DB, {
    category: normalizeCategory(body.category),
    severity: typeof body.severity === 'string' ? body.severity : undefined,
    errorCode: typeof body.errorCode === 'string' ? body.errorCode : undefined,
    title: typeof body.title === 'string' ? body.title : undefined,
    message: body.message as string,
    stackTrace: typeof body.stackTrace === 'string' ? body.stackTrace : undefined,
    context: body.context,
    source: 'flutter_app',
    screenOrEndpoint: typeof body.screenOrEndpoint === 'string' ? body.screenOrEndpoint : undefined,
    httpMethod: typeof body.httpMethod === 'string' ? body.httpMethod : undefined,
    httpStatus: typeof body.httpStatus === 'number' ? body.httpStatus : undefined,
    platform: typeof body.platform === 'string' ? body.platform : undefined,
    appVersion: typeof body.appVersion === 'string' ? body.appVersion : undefined,
    osVersion: typeof body.osVersion === 'string' ? body.osVersion : undefined,
    deviceModel: typeof body.deviceModel === 'string' ? body.deviceModel : undefined,
    locale: typeof body.locale === 'string' ? body.locale : undefined,
    userId: (body.userId as string | undefined) ?? userId ?? undefined,
    userRole: (body.userRole as string | undefined) ?? userRole ?? undefined,
  });

  return c.json({ success: true }, 201);
});

// ───────────────────────── فهرست (پنل مدیر) ──────────────────────────────────
errorLogs.get('/admin/error-logs', async (c) => {
  if (!(await requireAdmin(c, 'manage_error_logs'))) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  }

  const status = c.req.query('status');
  const severity = c.req.query('severity');
  const category = c.req.query('category');
  const from = c.req.query('from');
  const to = c.req.query('to');
  const q = c.req.query('q');
  const page = Math.max(1, parseInt(c.req.query('page') ?? '1', 10) || 1);
  const pageSize = Math.min(100, Math.max(1, parseInt(c.req.query('pageSize') ?? '25', 10) || 25));

  const where: string[] = [];
  const binds: any[] = [];
  if (status) { where.push('status = ?'); binds.push(status); }
  if (severity) { where.push('severity = ?'); binds.push(severity); }
  if (category) { where.push('category = ?'); binds.push(category.toUpperCase()); }
  if (from) { where.push('occurred_date >= ?'); binds.push(from); }
  if (to) { where.push('occurred_date <= ?'); binds.push(to); }
  if (q) { where.push('(message LIKE ? OR title LIKE ? OR error_code LIKE ?)'); binds.push(`%${q}%`, `%${q}%`, `%${q}%`); }
  const whereSql = where.length ? `WHERE ${where.join(' AND ')}` : '';

  const totalRow = await c.env.DB.prepare(`SELECT COUNT(*) AS total FROM error_logs ${whereSql}`)
    .bind(...binds)
    .first<{ total: number }>();

  const { results } = await c.env.DB.prepare(
    `SELECT id, error_code, category, severity, title, source, screen_or_endpoint,
            http_status, platform, occurred_at, occurred_date, occurred_day_of_week,
            occurred_time, status, occurrence_count
     FROM error_logs ${whereSql}
     ORDER BY occurred_at DESC
     LIMIT ? OFFSET ?`,
  )
    .bind(...binds, pageSize, (page - 1) * pageSize)
    .all();

  return c.json({ success: true, total: totalRow?.total ?? 0, page, pageSize, items: results });
});

// ───────────────────────── جزئیات ─────────────────────────────────────────
errorLogs.get('/admin/error-logs/:id', async (c) => {
  if (!(await requireAdmin(c, 'manage_error_logs'))) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  }
  const row = await c.env.DB.prepare('SELECT * FROM error_logs WHERE id = ?').bind(c.req.param('id')).first<any>();
  if (!row) return c.json(fail('NOT_FOUND', 'یافت نشد', 'Not found'), 404);
  if (row.context_json) {
    try { row.context = JSON.parse(row.context_json); } catch { row.context = row.context_json; }
  }
  return c.json({ success: true, ...row });
});

// ───────────────────────── تغییر وضعیت ─────────────────────────────────────
errorLogs.patch('/admin/error-logs/:id', async (c) => {
  const adminId = await requireAdmin(c, 'manage_error_logs');
  if (!adminId) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  }
  const body = await c.req.json<{ status?: string; resolutionNotes?: string }>().catch(() => null);
  const validStatuses = ['new', 'investigating', 'resolved', 'ignored'];
  if (!body?.status || !validStatuses.includes(body.status)) {
    return c.json(fail('BAD_REQUEST', `status باید یکی از ${validStatuses.join(', ')} باشد`, `status must be one of ${validStatuses.join(', ')}`), 400);
  }
  const resolvedAt = body.status === 'resolved' ? new Date().toISOString().replace('T', ' ').replace('Z', '') : null;
  await c.env.DB.prepare(
    `UPDATE error_logs
     SET status = ?, resolution_notes = COALESCE(?, resolution_notes),
         resolved_at = ?, resolved_by = CASE WHEN ? = 'resolved' THEN ? ELSE resolved_by END,
         updated_at = datetime('now')
     WHERE id = ?`,
  )
    .bind(body.status, body.resolutionNotes ?? null, resolvedAt, body.status, adminId, c.req.param('id'))
    .run();
  return c.json({ success: true });
});

// ───────────────────────── حذف ─────────────────────────────────────────────
errorLogs.delete('/admin/error-logs/:id', async (c) => {
  if (!(await requireAdmin(c, 'manage_error_logs'))) {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  }
  await c.env.DB.prepare('DELETE FROM error_logs WHERE id = ?').bind(c.req.param('id')).run();
  return c.json({ success: true });
});

export default errorLogs;
