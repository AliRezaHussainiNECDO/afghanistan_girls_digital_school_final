/**
 * lib/audit.ts — ثبت رویداد در جدول سراسری و غیرقابل‌تغییر `audit_logs`
 * (بخش ۲۰.۳ سند / Migration 0026).
 *
 * اصل طراحی: لاگ بازبینی هرگز نباید مسیر اصلی کاربر را بشکند یا کُند کند.
 *   • هر خطای درج فقط در console ثبت می‌شود (قابل‌مشاهده با `wrangler tail`).
 *   • در Handler ها ترجیحاً با `c.executionCtx.waitUntil(logAudit(...))`
 *     صدا زده شود تا پاسخ کاربر معطل درج لاگ نماند.
 *   • مقادیر JSON بزرگ (مثل Prompt کامل AI) برای محافظت از سقف اندازهٔ
 *     ردیف D1 در ~۳۰هزار نویسه بریده می‌شوند (با علامت‌گذاری صریح برش).
 */

export interface AuditEntry {
  /** شناسهٔ عامل؛ null یعنی سیستم یا کاربر ناشناس (مثل تلاش ورود ناموفق). */
  actorId?: string | null;
  actorRole?: string | null;
  /** نوع اقدام — مقادیر مستند در 0026_audit_logs.sql. */
  actionType: string;
  targetTable?: string | null;
  targetId?: string | null;
  reason?: string | null;
  beforeValue?: unknown;
  afterValue?: unknown;
  /** دادهٔ آزاد — برای `ai_invocation` شامل Prompt کامل (آرایهٔ messages). */
  detail?: unknown;
  ipAddress?: string | null;
  priority?: 'normal' | 'high';
}

const MAX_JSON_CHARS = 30_000;

function toJson(v: unknown): string | null {
  if (v === undefined || v === null) return null;
  try {
    const s = typeof v === 'string' ? v : JSON.stringify(v);
    if (s.length <= MAX_JSON_CHARS) return s;
    return JSON.stringify({ truncated: true, originalLength: s.length, data: s.slice(0, MAX_JSON_CHARS) });
  } catch (_) {
    return null;
  }
}

export async function logAudit(db: D1Database, e: AuditEntry): Promise<void> {
  try {
    await db
      .prepare(
        `INSERT INTO audit_logs
           (id, actor_id, actor_role, action_type, target_table, target_id, reason,
            before_value, after_value, detail, ip_address, priority)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        crypto.randomUUID(),
        e.actorId ?? null,
        e.actorRole ?? null,
        e.actionType,
        e.targetTable ?? null,
        e.targetId ?? null,
        e.reason ?? null,
        toJson(e.beforeValue),
        toJson(e.afterValue),
        toJson(e.detail),
        e.ipAddress ?? null,
        e.priority ?? 'normal',
      )
      .run();
  } catch (err) {
    // هرگز پرتاب نمی‌کنیم — شکست لاگ نباید عملیات اصلی را خراب کند.
    console.error('[audit] insert failed:', err);
  }
}

/** استخراج IP کلاینت پشت Cloudflare (پارامتر عمداً any — سازگار با هر Context هونو). */
export function clientIp(c: any): string | null {
  try {
    return (c?.req?.header?.('CF-Connecting-IP') as string | undefined) ?? null;
  } catch (_) {
    return null;
  }
}
