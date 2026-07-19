/**
 * routes/devices.ts — ثبت/حذف «توکن دستگاه» برای Push Notification واقعی
 * (FCM). اپ فلاتر بعد از ورود موفق (و گرفتن اجازهٔ اعلان از کاربر) این
 * Endpoint را صدا می‌زند تا توکن دستگاهش را با حساب کاربری‌اش پیوند بزند؛
 * موقع خروج از حساب هم `/devices/unregister` صدا زده می‌شود تا آن دستگاه
 * دیگر برای این کاربر Push نگیرد.
 *
 * Endpointها (زیر `/api/v1`):
 *   POST /devices/register     { token, platform } — Bearer اجباری
 *   POST /devices/unregister   { token }            — Bearer اجباری
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';

type Bindings = { DB: D1Database; JWT_SECRET: string };
const devices = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}
async function userId(c: any): Promise<string | null> {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return (payload?.['sub'] as string | undefined) ?? null;
}

devices.post('/devices/register', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const b = await c.req.json<{ token?: string; platform?: string }>().catch(() => null);
  const token = (b?.token ?? '').trim();
  if (!token) {
    return c.json(fail('BAD_REQUEST', 'توکن دستگاه الزامی است', 'Device token is required'), 400);
  }
  const platform = b?.platform && ['android', 'ios', 'web'].includes(b.platform) ? b.platform : 'android';

  // ON CONFLICT روی fcm_token (نه ترکیب کاربر+توکن): اگر همین گوشی قبلاً زیر
  // حساب کاربری دیگری ثبت شده بود (logout/login با کاربر تازه)، مالکیت به
  // کاربر تازه منتقل می‌شود — دقیقاً رفتار درست، چون توکن یعنی «این دستگاه»
  // نه «این کاربر».
  await c.env.DB.prepare(
    `INSERT INTO device_push_tokens (id, user_id, fcm_token, platform, updated_at)
     VALUES (?, ?, ?, ?, datetime('now'))
     ON CONFLICT(fcm_token) DO UPDATE SET user_id = excluded.user_id, platform = excluded.platform, updated_at = datetime('now')`,
  )
    .bind(crypto.randomUUID(), uid, token, platform)
    .run();

  return c.json({ success: true });
});

devices.post('/devices/unregister', async (c) => {
  const uid = await userId(c);
  if (!uid) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const b = await c.req.json<{ token?: string }>().catch(() => null);
  const token = (b?.token ?? '').trim();
  if (token) {
    await c.env.DB.prepare('DELETE FROM device_push_tokens WHERE fcm_token = ? AND user_id = ?')
      .bind(token, uid)
      .run()
      .catch(() => {});
  }
  return c.json({ success: true });
});

export default devices;
