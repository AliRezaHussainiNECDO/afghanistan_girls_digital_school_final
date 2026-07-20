/**
 * lib/geminiCache.ts — Context Caching گوگل برای چت «تمرکز مطلق بر درس».
 *
 * چرا: در هر پیام چتِ درس‌محور، کل متن درس (`lessons.content_body`) در
 * System Prompt می‌رود؛ یعنی هر سوال شاگرد = پرداخت/پردازش مجدد کل کتاب‌متن.
 * با Context Caching، متن درس یک بار در حافظهٔ گوگل ذخیره می‌شود
 * (`cachedContents/...`) و چت‌های بعدی فقط «نام کش» را می‌فرستند — توکن‌های
 * ورودی تکراری دیگر با نرخ کامل محاسبه نمی‌شوند.
 *
 * کاملاً Fail-safe (الگوی همین پروژه — lib/gemini.ts):
 *   • هر خطا (مدل بدون پشتیبانی کش، متن کوتاه‌تر از حداقل توکن، 429، شبکه،
 *     نبود ستون‌های مهاجرت ۰۰۳۳) → null → صدازننده مسیر قبلی
 *     (systemInstruction کامل) را ادامه می‌دهد. هیچ Endpointی کرش نمی‌کند.
 *
 * 🚨 خط قرمز: این ماژول فقط «بهینه‌سازی هزینه» است — هیچ دستی به منطق
 * امتیازدهی/پیشرفت/کارخانگی/قفل ندارد.
 */

const API_BASE = 'https://generativelanguage.googleapis.com/v1beta';

/** طول عمر هر کش (ثانیه) — یک ساعت: با الگوی مصرف «یک جلسه درس‌خواندن» می‌خواند. */
const CACHE_TTL_SECONDS = 3600;

/** متن‌های خیلی کوتاه ارزش کش ندارند (حداقل توکن API هم برآورده نمی‌شود). */
const MIN_CONTENT_CHARS = 4000;

type CacheEnv = {
  DB: D1Database;
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
};

/**
 * تضمین وجود کش معتبر برای System Prompt یک درس. نام کش معتبر (string) یا
 * null (→ مسیر بدون کش) برمی‌گرداند.
 */
export async function ensureLessonContextCache(
  env: CacheEnv,
  model: string,
  lessonId: string,
  systemPrompt: string,
): Promise<string | null> {
  if (!env.GEMINI_API_KEY) return null;
  if (systemPrompt.length < MIN_CONTENT_CHARS) return null;

  try {
    // ۱) کش ثبت‌شدهٔ معتبر؟ (با حاشیهٔ امن ۶۰ ثانیه)
    const row = await env.DB.prepare(
      'SELECT gemini_cache_name, cache_expires_at FROM lessons WHERE id = ?',
    )
      .bind(lessonId)
      .first<{ gemini_cache_name: string | null; cache_expires_at: string | null }>();

    if (
      row?.gemini_cache_name &&
      row.cache_expires_at &&
      new Date(row.cache_expires_at).getTime() - 60_000 > Date.now()
    ) {
      return row.gemini_cache_name;
    }

    // ۲) ساخت کش جدید
    const res = await fetch(`${API_BASE}/cachedContents?key=${env.GEMINI_API_KEY}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: `models/${model}`,
        displayName: `lesson-${lessonId}`.slice(0, 128),
        systemInstruction: { parts: [{ text: systemPrompt }] },
        ttl: `${CACHE_TTL_SECONDS}s`,
      }),
    });
    if (!res.ok) {
      // 400 (مدل/حداقل توکن)، 429، ... → بی‌صدا مسیر بدون کش
      console.error('[geminiCache] create failed:', res.status, (await res.text().catch(() => '')).slice(0, 200));
      return null;
    }

    const data = (await res.json()) as { name?: string };
    if (!data?.name) return null;

    const expiresAt = new Date(Date.now() + CACHE_TTL_SECONDS * 1000).toISOString();
    await env.DB.prepare('UPDATE lessons SET gemini_cache_name = ?, cache_expires_at = ? WHERE id = ?')
      .bind(data.name, expiresAt, lessonId)
      .run();

    return data.name;
  } catch (err) {
    console.error('[geminiCache] fallback (no cache):', err);
    return null;
  }
}
