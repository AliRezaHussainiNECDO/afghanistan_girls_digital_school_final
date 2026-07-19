/**
 * lib/push.ts — ارسال Push Notification واقعی به گوشی (حتی وقتی اپ کاملاً
 * بسته است) از طریق Firebase Cloud Messaging (FCM) — HTTP v1 API.
 *
 * چرا این‌قدر پیچیده (امضای JWT دستی به‌جای یک Server Key ساده)؟ چون گوگل
 * نسخهٔ قدیمیِ سادهٔ FCM (Legacy HTTP API با یک کلید ثابت) را در جون ۲۰۲۴
 * برای همیشه غیرفعال کرده؛ نسخهٔ فعلی (HTTP v1) نیاز به توکن OAuth2 دارد که
 * با گواهی یک Service Account (ایمیل + کلید خصوصی RSA، از کنسول Firebase)
 * امضا می‌شود. این‌جا آن امضا را با Web Crypto API خودِ Cloudflare Workers
 * انجام می‌دهیم — بدون هیچ کتابخانهٔ npm اضافه (که در Workers اصلاً معمولاً
 * کار نمی‌کنند چون به Node.js crypto نیاز دارند).
 *
 * پیکربندی (کاملاً اختیاری؛ در نبودشان هیچ Endpointی که این تابع را صدا
 * می‌زند کرش/کند نمی‌شود — دقیقاً همان اصل Fail-safe سرویس‌های AI/TTS این
 * پروژه):
 *   در Firebase Console → Project Settings → Service Accounts →
 *   «Generate new private key» یک فایل JSON دانلود می‌شود؛ سه مقدار زیر از
 *   همان فایل می‌آیند:
 *     wrangler secret put FCM_CLIENT_EMAIL     (فیلد client_email)
 *     wrangler secret put FCM_PRIVATE_KEY      (فیلد private_key — کامل، با \n ها)
 *     [vars] FCM_PROJECT_ID = "your-firebase-project-id"   (فیلد project_id، غیرمحرمانه)
 */

type PushEnv = {
  DB: D1Database;
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
};

// حافظهٔ موقت توکن OAuth2 در همین Isolate — از امضای دوبارهٔ JWT برای هر
// Push جلوگیری می‌کند (توکن‌های گوگل حدود ۱ ساعت اعتبار دارند). چون هر
// Isolate دیر یا زود دوباره ساخته می‌شود، این فقط یک بهینه‌سازی است، نه یک
// منبع حقیقت دائمی.
let cachedAccessToken: { token: string; expiresAt: number } | null = null;

function base64UrlEncode(input: ArrayBuffer | Uint8Array): string {
  const bytes = input instanceof Uint8Array ? input : new Uint8Array(input);
  let binary = '';
  for (let i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** PEM (با هدر/فوتر و \n یا \\n) را به ArrayBuffer خام DER تبدیل می‌کند. */
function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/, '')
    .replace(/-----END PRIVATE KEY-----/, '')
    .replace(/\\n/g, '')
    .replace(/\n/g, '')
    .replace(/\s+/g, '');
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
  return bytes.buffer;
}

/** توکن OAuth2 گوگل را با امضای JWT خودِ Service Account می‌گیرد (RFC 7523). */
async function getGoogleAccessToken(env: PushEnv): Promise<string | null> {
  if (!env.FCM_CLIENT_EMAIL || !env.FCM_PRIVATE_KEY) return null;
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt - 60 > now) return cachedAccessToken.token;

  try {
    const header = { alg: 'RS256', typ: 'JWT' };
    const claims = {
      iss: env.FCM_CLIENT_EMAIL,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    };
    const encoder = new TextEncoder();
    const unsigned =
      `${base64UrlEncode(encoder.encode(JSON.stringify(header)))}.` +
      base64UrlEncode(encoder.encode(JSON.stringify(claims)));

    const key = await crypto.subtle.importKey(
      'pkcs8',
      pemToArrayBuffer(env.FCM_PRIVATE_KEY),
      { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
      false,
      ['sign'],
    );
    const signature = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, encoder.encode(unsigned));
    const jwt = `${unsigned}.${base64UrlEncode(signature)}`;

    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: `grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${jwt}`,
    });
    if (!res.ok) {
      console.error('[push] Google OAuth2 token exchange failed —', res.status, await res.text().catch(() => ''));
      return null;
    }
    const data = (await res.json()) as { access_token?: string; expires_in?: number };
    if (!data.access_token) return null;
    cachedAccessToken = { token: data.access_token, expiresAt: now + (data.expires_in ?? 3600) };
    return data.access_token;
  } catch (err) {
    console.error('[push] Google OAuth2 token failed —', err);
    return null;
  }
}

/**
 * پیام Push را به تمام دستگاه‌های ثبت‌شدهٔ یک کاربر می‌فرستد. توکن‌های نامعتبر
 * (اپ حذف شده، یا کاربر Logout کرده) خودکار از دیتابیس پاک می‌شوند تا دفعهٔ
 * بعد دوباره تلاش بی‌فایده نشود (خوددرمانی).
 *
 * fail-safe کامل: نبود پیکربندی FCM، خطای شبکه، یا نبود دستگاه ثبت‌شده —
 * هیچ‌کدام Exception پرتاب نمی‌کنند؛ تابع فقط بی‌صدا برمی‌گردد.
 */
export async function sendPushToUser(
  env: PushEnv,
  userId: string,
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> {
  if (!env.FCM_PROJECT_ID) return; // سرویس هنوز پیکربندی نشده.
  try {
    const accessToken = await getGoogleAccessToken(env);
    if (!accessToken) return;

    const { results } = await env.DB.prepare('SELECT fcm_token FROM device_push_tokens WHERE user_id = ?')
      .bind(userId)
      .all<{ fcm_token: string }>();
    if (results.length === 0) return;

    await Promise.all(
      results.map(async (row) => {
        const res = await fetch(`https://fcm.googleapis.com/v1/projects/${env.FCM_PROJECT_ID}/messages:send`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${accessToken}` },
          body: JSON.stringify({
            message: {
              token: row.fcm_token,
              notification: { title, body },
              data: data ?? {},
            },
          }),
        });
        if (!res.ok) {
          const errText = await res.text().catch(() => '');
          if (errText.includes('UNREGISTERED') || errText.includes('NOT_FOUND') || errText.includes('INVALID_ARGUMENT')) {
            await env.DB.prepare('DELETE FROM device_push_tokens WHERE fcm_token = ?')
              .bind(row.fcm_token)
              .run()
              .catch(() => {});
          } else {
            console.error('[push] FCM send failed —', res.status, errText.slice(0, 300));
          }
        }
      }),
    );
  } catch (err) {
    console.error('[push] sendPushToUser failed —', err);
  }
}

/** نسخهٔ چندکاربره — برای اعلان‌های گروهی (مثلاً همهٔ ثبت‌نامی‌های سمینار). */
export async function sendPushToUsers(
  env: PushEnv,
  userIds: string[],
  title: string,
  body: string,
  data?: Record<string, string>,
): Promise<void> {
  await Promise.all(userIds.map((id) => sendPushToUser(env, id, title, body, data)));
}
