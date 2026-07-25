/**
 * lib/jaas.ts — صدور توکن JWT برای JaaS (Jitsi as a Service — 8x8.vc).
 *
 * چرا این لایه لازم شد؟ اتاق ویدیوکنفرانس سمینار (`SeminarRoomScreen` در
 * فلاتر) قبلاً بدون هیچ `serverURL`/`token` به Jitsi SDK وصل می‌شد که
 * به‌طور پیش‌فرض یعنی سرور عمومی و رایگان `meet.jit.si`. طبق تأیید صریح
 * نگهدارندگان خودِ Jitsi (github.com/jitsi/jitsi-meet-flutter-sdk، Issue
 * #42: «You cannot control authentication on meet.jit.si because that's a
 * deployment we maintain»)، احراز هویت/تعیین میزبان روی آن سرور در کنترل
 * ما نیست و می‌تواند به‌طور نامنظم با خطای «نیاز به میزبان» یا اختلال
 * روبه‌رو شود — برای مکتبی با شاگردان دختر، هم غیرقابل‌اتکا و هم از نظر
 * حریم خصوصی نامناسب (سروری که ما مالکش نیستیم).
 *
 * راه‌حل: JaaS (jaas.8x8.vc) — همان زیرساخت Jitsi ولی با احراز هویت واقعی
 * از طریق JWT امضاشده با کلید خصوصی RSA؛ رایگان تا ۲۵ کاربر فعال هم‌زمان.
 * این فایل فقط یک وظیفه دارد: ساخت و امضای همان JWT — بدون هیچ کتابخانهٔ
 * خارجی، فقط با Web Crypto API (السّابق راه‌حل HMAC در lib/auth.ts، اینجا
 * RS256 چون JaaS کلید نامتقارل می‌خواهد).
 *
 * تنظیم (اختیاری — اگر تنظیم نشود، سرور `configured: false` برمی‌گرداند و
 * اپ به رفتار قبلی/سرور عمومی برمی‌گردد؛ هیچ‌جا کرش نمی‌کند):
 *   1) در https://jaas.8x8.vc ثبت‌نام کنید، «App ID» (چیزی شبیه
 *      vpaas-magic-cookie-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx) را کپی کنید.
 *   2) از بخش «API Keys» یک کلید جدید بسازید؛ «Key ID» (kid) و فایل کلید
 *      خصوصی (PEM) را دانلود کنید.
 *   3) این سه مقدار را با wrangler به‌عنوان Secret ثبت کنید:
 *      wrangler secret put JAAS_APP_ID
 *      wrangler secret put JAAS_API_KEY_ID
 *      wrangler secret put JAAS_PRIVATE_KEY   (کل محتوای فایل .pk را جای‌گذاری کنید)
 */

export interface JaasEnv {
  JAAS_APP_ID?: string;
  JAAS_API_KEY_ID?: string;
  JAAS_PRIVATE_KEY?: string;
}

const enc = new TextEncoder();

function bytesToB64Url(bytes: Uint8Array): string {
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function strToB64Url(s: string): string {
  return bytesToB64Url(enc.encode(s));
}

/** آیا سرویس JaaS روی این محیط پیکربندی شده است؟ */
export function jaasConfigured(env: JaasEnv): boolean {
  return Boolean(env.JAAS_APP_ID && env.JAAS_API_KEY_ID && env.JAAS_PRIVATE_KEY);
}

/**
 * نام اتاق برای یک سمینار — دقیقاً همان قاعدهٔ سمت‌فلاتر
 * (`SeminarRoomScreen._roomNameFor`) تا هر دو طرف یک اتاق واحد بسازند.
 */
export function jaasRoomName(seminarId: string): string {
  return `agds${seminarId.replace(/[^a-zA-Z0-9]/g, '')}`;
}

/** تبدیل PEM (PKCS8) به کلید خصوصی قابل‌استفاده در SubtleCrypto. */
async function importJaasPrivateKey(pem: string): Promise<CryptoKey> {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');
  const bin = atob(clean);
  const der = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) der[i] = bin.charCodeAt(i);
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

export interface JaasTokenParams {
  room: string;
  userId: string;
  displayName: string;
  email?: string;
  moderator: boolean;
}

/**
 * صدور یک JWT امضاشده با RS256 برای ورود احرازهویت‌شده به یک اتاق JaaS —
 * محدود به همان اتاق (`room`) و کوتاه‌مدت (۲ ساعت) تا در صورت افشا هم
 * ریسک محدود بماند.
 */
export async function signJaasToken(env: JaasEnv, params: JaasTokenParams): Promise<string> {
  if (!jaasConfigured(env)) throw new Error('JaaS not configured');
  const appId = env.JAAS_APP_ID as string;
  const kid = env.JAAS_API_KEY_ID as string;
  const key = await importJaasPrivateKey(env.JAAS_PRIVATE_KEY as string);

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT', kid };
  const payload = {
    aud: 'jitsi',
    iss: 'chat',
    sub: appId,
    room: params.room,
    iat: now,
    nbf: now - 10,
    exp: now + 2 * 60 * 60,
    context: {
      user: {
        id: params.userId,
        name: params.displayName,
        email: params.email ?? '',
        moderator: params.moderator ? 'true' : 'false',
      },
      features: {
        livestreaming: 'false',
        recording: 'false',
        'outbound-call': 'false',
        transcription: 'false',
      },
    },
  };
  const data = `${strToB64Url(JSON.stringify(header))}.${strToB64Url(JSON.stringify(payload))}`;
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, enc.encode(data));
  return `${data}.${bytesToB64Url(new Uint8Array(sig))}`;
}
