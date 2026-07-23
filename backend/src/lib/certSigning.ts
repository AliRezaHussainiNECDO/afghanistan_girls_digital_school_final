/**
 * lib/certSigning.ts — امضای رمزنگاری‌شدهٔ (ECDSA P-256) دادهٔ گواهی‌نامه.
 *
 * چرا این‌طور، نه امضای واقعیِ PDF (سبک Adobe/PAdES)؟ Cloudflare Workers
 * نمی‌تواند یک امضای PDF استاندارد تولید کند (نیاز به کتابخانه‌های سنگین/
 * Node کامل دارد که در Workers اجرا نمی‌شوند). راه‌حل عملی و امن‌تر — دقیقاً
 * همان الگویی که Coursera/edX هم استفاده می‌کنند —: **منبع حقیقت خودِ رکورد
 * روی سرور است، نه فایل تصویری/PDف چاپ‌شده**. اگر کسی با فتوشاپ تصویر
 * گواهی را عوض کند، همان لحظه که کسی QR را اسکن می‌کند، صفحهٔ استعلام
 * دادهٔ واقعی (امضاشده و دوباره بررسی‌شده) را نشان می‌دهد — نه دادهٔ
 * دستکاری‌شده. امضا هم یک لایهٔ اضافه است: اثبات می‌کند این مقادیر دقیقاً
 * همان چیزی‌اند که سرور در لحظهٔ صدور امضا کرده (even اگر کسی مستقیماً به
 * دیتابیس دسترسی پیدا کند و رکورد را دستکاری کند، بدون کلید خصوصی نمی‌تواند
 * امضای معتبر جدید بسازد؛ صفحهٔ تأیید این ناهماهنگی را نشان می‌دهد).
 *
 * کلید خصوصی: `wrangler secret put CERT_SIGNING_PRIVATE_KEY` (PKCS8, Base64,
 * DER — یک‌بار تولید شد، هرگز در کد/گیت ذخیره نمی‌شود).
 * کلید عمومی: چون عمومی است (نه رازداری، بلکه فقط برای Verify)، مستقیم در
 * کد نگه داشته می‌شود.
 */

const PUBLIC_KEY_SPKI_B64 =
  'MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAE6e8Y1xumlNlYsiHGuDekQxeRQmoC0v1EFFrOtb3kgKBckRQP1hRfLpoLifTXiQ7anZuLVnev/VKSOm3GU194Ug==';

function b64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes;
}

function bytesToB64(bytes: ArrayBuffer): string {
  let bin = '';
  const arr = new Uint8Array(bytes);
  for (let i = 0; i < arr.length; i++) bin += String.fromCharCode(arr[i]);
  return btoa(bin);
}

export interface CertSignableData {
  serial: string;
  studentName: string;
  grade: number;
  yearLabel: string;
  average: number;
  issuedAt: string;
}

/** رشتهٔ Canonical که امضا می‌شود — ترتیب فیلدها هرگز نباید بعداً عوض شود
 * (وگرنه امضاهای قدیمی دیگر تأیید نمی‌شوند). */
function canonicalString(d: CertSignableData): string {
  return [d.serial, d.studentName, String(d.grade), d.yearLabel, String(d.average), d.issuedAt].join('|');
}

/** امضا فقط سمت صدور گواهی (نیاز به کلید خصوصی از env). در نبود کلید
 * (مثلاً محیط توسعهٔ محلی بدون secret)، رشتهٔ خالی برمی‌گرداند — گواهی
 * همچنان صادر می‌شود، فقط بدون نشان «امضا‌شده» در صفحهٔ تأیید. */
export async function signCertificate(
  env: { CERT_SIGNING_PRIVATE_KEY?: string },
  data: CertSignableData,
): Promise<string> {
  if (!env.CERT_SIGNING_PRIVATE_KEY) return '';
  try {
    const key = await crypto.subtle.importKey(
      'pkcs8',
      b64ToBytes(env.CERT_SIGNING_PRIVATE_KEY),
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['sign'],
    );
    const sig = await crypto.subtle.sign(
      { name: 'ECDSA', hash: 'SHA-256' },
      key,
      new TextEncoder().encode(canonicalString(data)),
    );
    return bytesToB64(sig);
  } catch {
    return '';
  }
}

/** بررسی امضا — با کلید عمومیِ ثابت بالا؛ نیازی به env ندارد. */
export async function verifyCertificateSignature(
  data: CertSignableData,
  signatureB64: string,
): Promise<boolean> {
  if (!signatureB64) return false;
  try {
    const key = await crypto.subtle.importKey(
      'spki',
      b64ToBytes(PUBLIC_KEY_SPKI_B64),
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['verify'],
    );
    return await crypto.subtle.verify(
      { name: 'ECDSA', hash: 'SHA-256' },
      key,
      b64ToBytes(signatureB64),
      new TextEncoder().encode(canonicalString(data)),
    );
  } catch {
    return false;
  }
}
