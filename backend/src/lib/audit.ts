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

/**
 * رفع اشکال «صفحه‌بندی لاگ بازبینی بی‌صدا ردیف حذف می‌کند»: قبلاً `created_at`
 * را به DEFAULT ستون (`datetime('now')`، دقت فقط تا ثانیه) واگذار می‌کردیم.
 * صفحه‌بندی سرشماره‌ای سمت کلاینت (`GET /admin/audit-logs?before=<آخرین
 * created_at>`) با مقایسهٔ رشته‌ای `created_at < ?` کار می‌کند؛ اگر دو یا چند
 * اقدام مدیر (مثلاً صدور دسته‌ای کد دعوت، یا انتشار نصاب + Embedding) درست در
 * همان یک ثانیه ثبت می‌شدند، مقدار `created_at`شان کاملاً یکسان می‌شد و در
 * صفحهٔ بعد، هر ردیفِ هم‌زمانِ دیگر برای همیشه نادیده گرفته می‌شد — یک نشتِ
 * خاموشِ داده در دقیقاً همان جایی (مسیر بازبینی امنیتی) که نباید هیچ ردیفی
 * گم شود.
 *
 * راه‌حل: خودمان `created_at` را با دقت میلی‌ثانیه می‌سازیم و صریحاً INSERT
 * می‌کنیم — با همان قالب `YYYY-MM-DD HH:MM:SS[.sss]` که `datetime('now')`
 * تولید می‌کرد (نه فرمت ISO با `T`/`Z`) تا ترتیب رشته‌ای (لغوی) با ردیف‌های
 * قدیمی‌تر هم سازگار بماند. برخورد دو اقدام در یک میلی‌ثانیهٔ دقیق عملاً
 * غیرممکن است، پس این مشکل را در عمل به‌طور کامل برطرف می‌کند — بدون نیاز به
 * تغییر قرارداد صفحه‌بندی سمت کلاینت (فلاتر همچنان همان رشته را عیناً پس
 * می‌فرستد).
 */
function preciseTimestamp(): string {
  return new Date().toISOString().replace('T', ' ').replace('Z', '');
}

export async function logAudit(db: D1Database, e: AuditEntry): Promise<void> {
  try {
    await db
      .prepare(
        `INSERT INTO audit_logs
           (id, actor_id, actor_role, action_type, target_table, target_id, reason,
            before_value, after_value, detail, ip_address, priority, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
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
        preciseTimestamp(),
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
