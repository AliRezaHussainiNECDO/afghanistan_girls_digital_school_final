/**
 * lib/auth.ts — رمزنگاری رمز عبور و JWT، فقط با Web Crypto API.
 *
 * چرا bcrypt نه؟ bcrypt یک ماژول Native نود است و روی Cloudflare Workers
 * (که Node runtime ندارند) اجرا نمی‌شود. به‌جای آن از PBKDF2 (استاندارد،
 * موجود در SubtleCrypto) استفاده می‌کنیم — بدون هیچ وابستگی خارجی و امن.
 * اگر حتماً bcrypt می‌خواهید، تنها گزینهٔ سازگار `bcryptjs` (خالص JS) است؛
 * اما PBKDF2 در اینجا سریع‌تر و بدون dependency است.
 */

const enc = new TextEncoder();
const dec = new TextDecoder();

// تعداد تکرار PBKDF2 — تعادل امنیت/کارایی روی Workers.
const PBKDF2_ITERATIONS = 100_000;
const PBKDF2_KEYLEN_BITS = 256;

// ───────────────────────────── Base64 helpers ─────────────────────────────

function bytesToB64(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin);
}

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToB64Url(bytes: Uint8Array): string {
  return bytesToB64(bytes).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function b64UrlToBytes(s: string): Uint8Array {
  const pad = s.length % 4 === 0 ? '' : '='.repeat(4 - (s.length % 4));
  return b64ToBytes(s.replace(/-/g, '+').replace(/_/g, '/') + pad);
}

function strToB64Url(s: string): string {
  return bytesToB64Url(enc.encode(s));
}

/** مقایسهٔ زمان‌ثابت برای جلوگیری از Timing Attack. */
function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

// ─────────────────────────── Password hashing ─────────────────────────────

async function pbkdf2(password: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
  const keyMaterial = await crypto.subtle.importKey(
    'raw',
    enc.encode(password),
    'PBKDF2',
    false,
    ['deriveBits'],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: 'PBKDF2', salt, iterations, hash: 'SHA-256' },
    keyMaterial,
    PBKDF2_KEYLEN_BITS,
  );
  return new Uint8Array(bits);
}

/**
 * هش رمز عبور. خروجی خودتوصیف است: `pbkdf2$<iter>$<saltB64>$<hashB64>`
 * تا در آینده تغییر پارامترها بدون شکستن رمزهای موجود ممکن باشد.
 */
export async function hashPassword(password: string): Promise<string> {
  const salt = crypto.getRandomValues(new Uint8Array(16));
  const hash = await pbkdf2(password, salt, PBKDF2_ITERATIONS);
  return `pbkdf2$${PBKDF2_ITERATIONS}$${bytesToB64(salt)}$${bytesToB64(hash)}`;
}

/** اعتبارسنجی رمز در برابر هش ذخیره‌شده. */
export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split('$');
  if (parts.length !== 4 || parts[0] !== 'pbkdf2') return false;
  const iterations = parseInt(parts[1], 10);
  const salt = b64ToBytes(parts[2]);
  const expected = parts[3];
  const computed = bytesToB64(await pbkdf2(password, salt, iterations));
  return timingSafeEqual(computed, expected);
}

// ─────────────────────────────── JWT (HS256) ──────────────────────────────

async function hmacSign(data: string, secret: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    enc.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', key, enc.encode(data));
  return bytesToB64Url(new Uint8Array(sig));
}

export interface JwtPayload {
  sub: string; // user id
  [key: string]: unknown;
}

/**
 * صدور یک JWT امضاشده با HS256.
 * [expiresInSec] پیش‌فرض ۹۰۰ ثانیه (۱۵ دقیقه) — مطابق Access Token بخش ۳.۳.
 */
export async function signJwt(
  payload: JwtPayload,
  secret: string,
  expiresInSec = 900,
): Promise<string> {
  const header = { alg: 'HS256', typ: 'JWT' };
  const now = Math.floor(Date.now() / 1000);
  const body = { ...payload, iat: now, exp: now + expiresInSec };
  const data = `${strToB64Url(JSON.stringify(header))}.${strToB64Url(JSON.stringify(body))}`;
  const sig = await hmacSign(data, secret);
  return `${data}.${sig}`;
}

/**
 * تأیید امضا و انقضای JWT. در صورت اعتبار، payload را برمی‌گرداند؛ در غیر
 * این صورت null (بدون پرتاب استثنا).
 */
export async function verifyJwt(token: string, secret: string): Promise<Record<string, unknown> | null> {
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const [h, p, s] = parts;
  const expected = await hmacSign(`${h}.${p}`, secret);
  if (!timingSafeEqual(s, expected)) return null;
  try {
    const payload = JSON.parse(dec.decode(b64UrlToBytes(p))) as Record<string, unknown>;
    const exp = payload['exp'];
    if (typeof exp === 'number' && Math.floor(Date.now() / 1000) > exp) return null;
    return payload;
  } catch {
    return null;
  }
}

/** استخراج و تأیید Token از هدر `Authorization: Bearer <token>`. */
export async function verifyBearer(
  authHeader: string | undefined,
  secret: string,
): Promise<Record<string, unknown> | null> {
  if (!authHeader || !authHeader.startsWith('Bearer ')) return null;
  return verifyJwt(authHeader.slice(7).trim(), secret);
}
