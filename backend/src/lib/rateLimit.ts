/**
 * lib/rateLimit.ts — محدودیت نرخ سبک بر پایهٔ D1 (جدول `rate_limit_hits`،
 * Migration 0035) برای Endpointهای حساس به Brute-force/هرزنامه — بدون نیاز
 * به KV یا Durable Object جدید که تنظیم دستی در داشبورد Cloudflare می‌خواهد.
 *
 * طراحی: هر تلاش یک ردیف با یک کلید مشخص (مثلاً `login:<ip>` یا
 * `register:<ip>`) ثبت می‌کند. اگر تعداد ردیف‌های همان کلید در بازهٔ زمانی
 * از سقف مجاز بیشتر شود، فراخوان باید ۴۲۹ برگرداند. ردیف‌های قدیمی‌تر از
 * بازه در همان فراخوانی پاک می‌شوند تا جدول کوچک بماند (بر خلاف audit_logs
 * که عمداً Append-only/غیرقابل‌حذف است).
 *
 * Fail-safe: هر خطای D1 (مثلاً محیطی که هنوز Migration 0035 روی آن اجرا
 * نشده) باعث رد شدن بدون قفل می‌شود — امنیت هرگز نباید کاربر واقعی را قفل
 * کند یا کل Endpoint را از کار بیندازد (همان اصل Fail-safe در کل این پروژه).
 */

export async function hitRateLimit(
  db: D1Database,
  key: string,
  windowSeconds: number,
  maxHits: number,
): Promise<{ limited: boolean }> {
  try {
    const cutoff = `-${windowSeconds} seconds`;
    // پاک‌سازی ردیف‌های خارج از بازه برای همین کلید — جدول را کوچک نگه می‌دارد.
    await db
      .prepare(`DELETE FROM rate_limit_hits WHERE rl_key = ? AND created_at <= datetime('now', ?)`)
      .bind(key, cutoff)
      .run();

    const { results } = await db
      .prepare(`SELECT COUNT(*) AS n FROM rate_limit_hits WHERE rl_key = ? AND created_at > datetime('now', ?)`)
      .bind(key, cutoff)
      .all<{ n: number }>();
    const n = Number(results?.[0]?.n ?? 0);
    if (n >= maxHits) return { limited: true };

    await db.prepare(`INSERT INTO rate_limit_hits (rl_key, created_at) VALUES (?, datetime('now'))`).bind(key).run();
    return { limited: false };
  } catch (_) {
    return { limited: false }; // Fail-open — هرگز روند اصلی کاربر را نمی‌شکند.
  }
}

/** پاسخ استاندارد ۴۲۹ — هر ۴ زبان برنامه. */
export function rateLimitFail() {
  return {
    success: false,
    error: {
      code: 'RATE_LIMITED',
      message_fa: 'تلاش‌های زیادی از این آدرس ثبت شده — لطفاً چند دقیقه صبر کنید و دوباره امتحان کنید.',
      message_en: 'Too many attempts from this address — please wait a few minutes and try again.',
      message_ps: 'له دې پته نه ډیری هڅې شوي — مهرباني وکړئ څو دقیقې صبر وکړئ.',
      message_fr: 'Trop de tentatives depuis cette adresse — veuillez patienter quelques minutes et réessayer.',
    },
  };
}
