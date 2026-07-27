/**
 * lib/errorLog.ts — ثبت خطای اجرایی در جدول `error_logs` (Migration 0046).
 *
 * همان اصل lib/audit.ts: هرگز نباید مسیر اصلی را بشکند یا کُند کند — هر خطای
 * درج فقط در console ثبت می‌شود. در Handlerهای Worker ترجیحاً با
 * `c.executionCtx.waitUntil(captureError(...))` صدا زده شود.
 *
 * استفاده:
 *   • خودکار: `app.onError` در src/index.ts هر استثنای مدیریت‌نشدهٔ Worker را
 *     از اینجا می‌گذراند — نیازی به تغییر دستی هر Route نیست.
 *   • دستی: هر Handler می‌تواند در try/catch خودش هم صریحاً صدا بزند تا
 *     category/severity دقیق‌تری (مثلاً 'AUTH' برای شکست ورود) ثبت شود.
 *   • اپ فلاتر: از همین جدول از طریق `POST /api/v1/errors` (routes/errorLogs.ts)
 *     پر می‌شود — نگاه کن core/errors/app_error_handler.dart.
 */

export type ErrorCategory = 'AUTH' | 'DATABASE' | 'API' | 'UI' | 'VALIDATION' | 'NETWORK' | 'UNKNOWN';
export type ErrorSeverity = 'low' | 'medium' | 'high' | 'critical';

const CATEGORY_PREFIX: Record<ErrorCategory, string> = {
  AUTH: 'AUTH',
  DATABASE: 'DB',
  API: 'API',
  UI: 'UI',
  VALIDATION: 'VALID',
  NETWORK: 'NETWORK',
  UNKNOWN: 'UNKNOWN',
};

const VALID_CATEGORIES = Object.keys(CATEGORY_PREFIX) as ErrorCategory[];
const VALID_SEVERITIES: ErrorSeverity[] = ['low', 'medium', 'high', 'critical'];

export function normalizeCategory(v: unknown): ErrorCategory {
  const up = String(v ?? '').toUpperCase();
  return (VALID_CATEGORIES as string[]).includes(up) ? (up as ErrorCategory) : 'UNKNOWN';
}

export function normalizeSeverity(v: unknown): v is ErrorSeverity {
  return (VALID_SEVERITIES as string[]).includes(String(v ?? ''));
}

/** کد پایدار مثل "AUTH-401" یا "DB-1062" — detail معمولاً HTTP status است. */
export function generateErrorCode(category: ErrorCategory, detail?: string | number | null): string {
  const prefix = CATEGORY_PREFIX[category] ?? CATEGORY_PREFIX.UNKNOWN;
  const suffix = detail === undefined || detail === null || detail === '' ? '000' : String(detail);
  return `${prefix}-${suffix}`;
}

export function defaultSeverityFor(category: ErrorCategory, httpStatus?: number | null): ErrorSeverity {
  if (category === 'DATABASE') return 'critical';
  if (category === 'AUTH') return 'high';
  if (httpStatus && httpStatus >= 500) return 'critical';
  if (httpStatus && httpStatus >= 400) return 'medium';
  return 'medium';
}

/** هش سبک و پایدار — فقط برای تشخیص «همین خطا دوباره تکرار شده»، نه امنیتی. */
export function makeFingerprint(parts: { errorCode: string; screenOrEndpoint?: string | null; message?: string | null }): string {
  const raw = `${parts.errorCode}|${parts.screenOrEndpoint ?? ''}|${(parts.message ?? '').slice(0, 200)}`;
  let hash = 0;
  for (let i = 0; i < raw.length; i++) hash = (hash * 31 + raw.charCodeAt(i)) | 0;
  return `fp_${Math.abs(hash)}`;
}

/** همان قالب `YYYY-MM-DD HH:MM:SS.sss` که lib/audit.ts برای audit_logs استفاده می‌کند. */
function preciseTimestamp(d: Date = new Date()): string {
  return d.toISOString().replace('T', ' ').replace('Z', '');
}

const DAY_NAMES_FA = ['یکشنبه', 'دوشنبه', 'سه‌شنبه', 'چهارشنبه', 'پنجشنبه', 'جمعه', 'شنبه']; // getUTCDay(): 0=یکشنبه

export interface ErrorLogInput {
  category: ErrorCategory | string;
  message: string;
  title?: string | null;
  severity?: ErrorSeverity | string | null;
  errorCode?: string | null;
  stackTrace?: string | null;
  context?: unknown;
  source: 'flutter_app' | 'cloudflare_worker';
  screenOrEndpoint?: string | null;
  httpMethod?: string | null;
  httpStatus?: number | null;
  platform?: string | null;
  appVersion?: string | null;
  osVersion?: string | null;
  deviceModel?: string | null;
  locale?: string | null;
  userId?: string | null;
  userRole?: string | null;
}

const MAX_JSON_CHARS = 30_000;
function toJson(v: unknown): string | null {
  if (v === undefined || v === null) return null;
  try {
    const s = typeof v === 'string' ? v : JSON.stringify(v);
    return s.length <= MAX_JSON_CHARS ? s : JSON.stringify({ truncated: true, originalLength: s.length, data: s.slice(0, MAX_JSON_CHARS) });
  } catch {
    return null;
  }
}

/**
 * ثبت یک خطا. اگر دقیقاً همین خطا (fingerprint یکسان) اخیراً و هنوز
 * حل‌نشده ثبت شده باشد، به‌جای ردیف تازه فقط occurrence_count را بالا
 * می‌برد — تا یک باگ پرتکرار هزاران ردیف یکسان تولید نکند.
 */
export async function captureError(db: D1Database, input: ErrorLogInput): Promise<void> {
  try {
    const category = normalizeCategory(input.category);
    const severity: ErrorSeverity = normalizeSeverity(input.severity) ? (input.severity as ErrorSeverity) : defaultSeverityFor(category, input.httpStatus ?? undefined);
    const errorCode = input.errorCode || generateErrorCode(category, input.httpStatus ?? undefined);
    const now = new Date();
    const occurredAt = preciseTimestamp(now);
    const fingerprint = makeFingerprint({ errorCode, screenOrEndpoint: input.screenOrEndpoint, message: input.message });

    const existing = await db
      .prepare(`SELECT id, occurrence_count FROM error_logs WHERE fingerprint = ? AND status != 'resolved' ORDER BY created_at DESC LIMIT 1`)
      .bind(fingerprint)
      .first<{ id: string; occurrence_count: number }>();

    if (existing) {
      await db
        .prepare(`UPDATE error_logs SET occurrence_count = occurrence_count + 1, occurred_at = ?, updated_at = ? WHERE id = ?`)
        .bind(occurredAt, occurredAt, existing.id)
        .run();
      return;
    }

    await db
      .prepare(
        `INSERT INTO error_logs (
           id, error_code, category, severity, title, message, stack_trace, context_json,
           source, screen_or_endpoint, http_method, http_status,
           platform, app_version, os_version, device_model, locale,
           user_id, user_role,
           occurred_at, occurred_date, occurred_day_of_week, occurred_time,
           status, fingerprint, created_at, updated_at
         ) VALUES (?,?,?,?,?,?,?,?, ?,?,?,?, ?,?,?,?,?, ?,?, ?,?,?,?, 'new', ?, ?, ?)`,
      )
      .bind(
        crypto.randomUUID(),
        errorCode,
        category,
        severity,
        (input.title || input.message || 'خطای ناشناخته').slice(0, 200),
        input.message ?? String(input.message),
        input.stackTrace ?? null,
        toJson(input.context),
        input.source,
        input.screenOrEndpoint ?? null,
        input.httpMethod ?? null,
        input.httpStatus ?? null,
        input.platform ?? null,
        input.appVersion ?? null,
        input.osVersion ?? null,
        input.deviceModel ?? null,
        input.locale ?? null,
        input.userId ?? null,
        input.userRole ?? null,
        occurredAt,
        occurredAt.slice(0, 10),
        DAY_NAMES_FA[now.getUTCDay()],
        occurredAt.slice(11, 19),
        fingerprint,
        occurredAt,
        occurredAt,
      )
      .run();
  } catch (err) {
    // هرگز پرتاب نمی‌کنیم — شکست ثبتِ خطا نباید عملیات اصلی را خراب کند.
    console.error('[errorLog] insert failed:', err, 'original:', input?.message);
  }
}
