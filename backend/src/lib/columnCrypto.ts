/**
 * lib/columnCrypto.ts — رمزنگاری/رمزگشایی سطح-ستون با AES-256-GCM، برای PII
 * حساس در D1 (شمارهٔ تلفن، تاریخ تولد — بند «رمزگذاری ستونی» در docs/02).
 *
 * چرا AES-GCM (نه چیزی مثل PBKDF2 که برای رمز عبور استفاده شده)؟ رمز عبور
 * هرگز نباید rmزگشایی شود (فقط مقایسه‌شدنی)، اما این فیلدها باید در پنل مدیر
 * به‌صورت خوانا نمایش داده شوند — پس رمزنگاریِ دوطرفهٔ متقارن لازم است، نه هش.
 * AES-GCM هم رمزنگاری می‌کند و هم صحت را تضمین می‌کند (Authenticated
 * Encryption) — اگر متن رمزشده دستکاری شود، رمزگشایی شکست می‌خورد (نه اینکه
 * بی‌صدا داده‌ای خراب برگرداند).
 *
 * فرمت ذخیره‌سازی: base64(IV دوازده‌بایتی || متن رمزشده+GCM tag) — یک رشتهٔ
 * متنی ساده که در همان ستون TEXT فعلی D1 جا می‌شود.
 *
 * کلید: `env.COLUMN_ENCRYPTION_KEY` — Base64 دقیقاً ۳۲ بایت (AES-256)، با
 * `wrangler secret put COLUMN_ENCRYPTION_KEY` تنظیم می‌شود، هرگز در
 * wrangler.toml یا Git.
 *
 * Fail-safe (هم‌سو با کل پروژه): در نبود کلید یا هر خطای رمزنگاری/رمزگشایی،
 * این ماژول هرگز پرتاب (throw) نمی‌کند و کل درخواست کاربر را نمی‌شکند —
 * `encryptField` مقدار null برمی‌گرداند (فراخوان باید به ستون متن‌سادهٔ قدیمی
 * برگردد) و `decryptField` رشتهٔ خالی برمی‌گرداند.
 */

export type CryptoBindings = { COLUMN_ENCRYPTION_KEY?: string };

let cachedKeyRaw: string | null = null;
let cachedKeyPromise: Promise<CryptoKey> | null = null;

function getKey(env: CryptoBindings): Promise<CryptoKey> | null {
  const raw = env.COLUMN_ENCRYPTION_KEY;
  if (!raw) return null;
  if (cachedKeyRaw === raw && cachedKeyPromise) return cachedKeyPromise;
  cachedKeyRaw = raw;
  cachedKeyPromise = (async () => {
    const keyBytes = Uint8Array.from(atob(raw), (ch) => ch.charCodeAt(0));
    if (keyBytes.length !== 32) {
      throw new Error(`COLUMN_ENCRYPTION_KEY must decode to exactly 32 bytes, got ${keyBytes.length}`);
    }
    return crypto.subtle.importKey('raw', keyBytes, { name: 'AES-GCM' }, false, ['encrypt', 'decrypt']);
  })();
  return cachedKeyPromise;
}

function toBase64(bytes: Uint8Array): string {
  let bin = '';
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

function fromBase64(b64: string): Uint8Array {
  return Uint8Array.from(atob(b64), (ch) => ch.charCodeAt(0));
}

/** رمزنگاری یک مقدار متنی — null برمی‌گرداند اگر کلید تنظیم نشده باشد یا
 * ورودی خالی باشد (فراخوان باید در این حالت به ستون قدیمیِ متن‌ساده برگردد،
 * نه اینکه یک رشتهٔ خالیِ «رمزشده» بی‌معنا ذخیره کند). */
export async function encryptField(env: CryptoBindings, plaintext: string | null | undefined): Promise<string | null> {
  if (!plaintext) return null;
  const keyPromise = getKey(env);
  if (!keyPromise) return null;
  try {
    const key = await keyPromise;
    const iv = crypto.getRandomValues(new Uint8Array(12));
    const encoded = new TextEncoder().encode(plaintext);
    const cipher = await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, key, encoded);
    const combined = new Uint8Array(iv.length + cipher.byteLength);
    combined.set(iv, 0);
    combined.set(new Uint8Array(cipher), iv.length);
    return toBase64(combined);
  } catch (e) {
    console.error('[columnCrypto] encryptField failed:', (e as Error)?.message);
    return null;
  }
}

/** رمزگشایی — رشتهٔ خالی برمی‌گرداند در هر حالت خطا (کلید نبودن، دادهٔ
 * دستکاری‌شده، یا کلید عوض‌شده) به‌جای شکستن کل درخواست. */
export async function decryptField(env: CryptoBindings, ciphertextB64: string | null | undefined): Promise<string> {
  if (!ciphertextB64) return '';
  const keyPromise = getKey(env);
  if (!keyPromise) return '';
  try {
    const key = await keyPromise;
    const combined = fromBase64(ciphertextB64);
    const iv = combined.slice(0, 12);
    const cipher = combined.slice(12);
    const plainBuf = await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, key, cipher);
    return new TextDecoder().decode(plainBuf);
  } catch (e) {
    console.error('[columnCrypto] decryptField failed:', (e as Error)?.message);
    return '';
  }
}

/** یک ردیف کاربر با هر دو ستون (رمزشدهٔ جدید + متن‌سادهٔ قدیمی) را به مقدار
 * نهاییِ قابل‌نمایش تبدیل می‌کند — رمزشده در اولویت است؛ اگر نبود (سطر قدیمیِ
 * هنوز Backfill‌نشده)، به ستون متن‌سادهٔ قدیمی برمی‌گردد. این تابع مشترک در
 * تمام Endpointهای مدیر که تلفن/تاریخ تولد را نمایش می‌دهند استفاده می‌شود
 * تا منطق fallback یک‌بار نوشته شود، نه در هر Endpoint جداگانه. */
export async function resolveEncryptedContact(
  env: CryptoBindings,
  row: { phone?: string | null; phone_enc?: string | null; date_of_birth?: string | null; dob_enc?: string | null },
): Promise<{ phone: string; dateOfBirth: string }> {
  const phone = row.phone_enc ? await decryptField(env, row.phone_enc) : row.phone ?? '';
  const dateOfBirth = row.dob_enc ? await decryptField(env, row.dob_enc) : row.date_of_birth ?? '';
  return { phone, dateOfBirth };
}
