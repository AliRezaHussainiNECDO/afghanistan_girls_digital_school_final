/**
 * routes/auth.ts — روتر احراز هویت (بخش ۳ و ۱۹.۱ سند).
 *
 * Endpointها (زیر `/api/v1/auth`):
 *   POST /register         ثبت‌نام با بررسی Invite Code + هش رمز + صدور JWT
 *   POST /login            تأیید ایمیل/رمز + صدور JWT
 *   POST /refresh          تمدید Access Token با Refresh Token (Rotation)
 *   POST /logout           ابطال Refresh Token
 *   GET  /me               کاربر فعلی از روی Access Token
 *   GET  /verify-email     تأیید ایمیل با توکن لینک (صفحهٔ HTML)
 *   POST /resend-verification  ارسال مجدد لینک تأیید ایمیل
 *   POST /forgot-password  ارسال کد ۶ رقمی بازیابی به ایمیل
 *   POST /reset-password   تغییر رمز با کد ۶ رقمی
 */
import { Hono } from 'hono';
import { hashPassword, verifyPassword, signJwt, verifyJwt, verifyBearer } from '../lib/auth';
import {
  sendEmail,
  verificationEmailHtml,
  resetEmailHtml,
  sha256B64Url,
  randomToken,
  randomSixDigitCode,
} from '../lib/email';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  RESEND_API_KEY?: string;
  EMAIL_FROM?: string;
};

const ACCESS_TTL = 60 * 15; // ۱۵ دقیقه (بخش ۳.۳)
const REFRESH_TTL = 60 * 60 * 24 * 30; // ۳۰ روز

const auth = new Hono<{ Bindings: Bindings }>();

const uid = () => crypto.randomUUID();

/** پاسخ خطای استاندارد مطابق قرارداد بخش ۱۹.۱۰ سند. */
function fail(code: string, messageFa: string, messageEn: string) {
  return { success: false, error: { code, message_fa: messageFa, message_en: messageEn } };
}

interface UserRow {
  id: string;
  email: string;
  password_hash: string;
  first_name: string;
  last_name: string;
  role: string;
  status: string;
  current_grade: number | null;
  awaiting_parent_link: number;
  email_verified: number;
  avatar_url: string | null;
}

/** خروجی امن کاربر (بدون هش رمز) — کلیدها هماهنگ با AuthRemoteDataSource فلاتر. */
function publicUser(u: UserRow) {
  return {
    id: u.id,
    email: u.email,
    first_name: u.first_name,
    last_name: u.last_name,
    role: u.role,
    current_grade: u.current_grade,
    awaiting_parent_link: u.awaiting_parent_link === 1,
    email_verified: u.email_verified === 1,
    avatar_url: u.avatar_url,
  };
}

// ─────────────────────── تأیید ایمیل — کمک‌کننده‌ها ─────────────────────────

const VERIFY_TTL_HOURS = 48; // اعتبار لینک تأیید ایمیل
const RESET_TTL_MIN = 15; // اعتبار کد ۶ رقمی بازیابی
const RESET_MAX_ATTEMPTS = 5; // حداکثر تلاش برای یک کد

/** ساخت توکن تأیید، ذخیرهٔ هش آن، و ارسال ایمیل حاوی لینک تأیید. */
async function sendVerificationEmail(
  env: Bindings,
  requestUrl: string,
  user: { id: string; email: string; first_name: string },
): Promise<void> {
  const token = randomToken();
  const tokenHash = await sha256B64Url(token);
  const expiresAt = new Date(Date.now() + VERIFY_TTL_HOURS * 3600_000).toISOString();
  // توکن‌های تأیید قبلی این کاربر باطل می‌شوند (فقط آخرین لینک معتبر است).
  await env.DB.batch([
    env.DB.prepare("UPDATE email_tokens SET used = 1 WHERE user_id = ? AND type = 'verify'").bind(
      user.id,
    ),
    env.DB.prepare(
      "INSERT INTO email_tokens (id, user_id, type, token_hash, expires_at) VALUES (?, ?, 'verify', ?, ?)",
    ).bind(crypto.randomUUID(), user.id, tokenHash, expiresAt),
  ]);
  const origin = new URL(requestUrl).origin;
  const verifyUrl = `${origin}/api/v1/auth/verify-email?token=${token}`;
  await sendEmail(
    env,
    user.email,
    'تأیید ایمیل — مکتب دیجیتال دختران افغانستان',
    verificationEmailHtml(user.first_name, verifyUrl),
  );
}

/** صفحهٔ سادهٔ HTML (راست‌به‌چپ) برای نتیجهٔ کلیک روی لینک تأیید. */
function verifyResultPage(ok: boolean, message: string): string {
  const color = ok ? '#1b6e4b' : '#b3261e';
  const icon = ok ? '✅' : '❌';
  return `<!doctype html>
<html dir="rtl" lang="fa"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>مکتب دیجیتال دختران افغانستان</title></head>
<body style="margin:0;background:#f4f6f8;font-family:Tahoma,'Segoe UI',sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;">
<div style="background:#fff;border:1px solid #e3e8ee;border-radius:12px;padding:40px 32px;max-width:420px;text-align:center;">
  <div style="font-size:48px;">${icon}</div>
  <h2 style="color:${color};margin:16px 0 8px;">${message}</h2>
  <p style="color:#7b8794;font-size:13px;">اکنون می‌توانید به اپلیکیشن برگردید.</p>
</div></body></html>`;
}

async function issueTokens(db: D1Database, secret: string, u: UserRow) {
  const jti = uid();
  const expiresAt = new Date(Date.now() + REFRESH_TTL * 1000).toISOString();
  await db
    .prepare('INSERT INTO refresh_tokens (id, user_id, expires_at) VALUES (?, ?, ?)')
    .bind(jti, u.id, expiresAt)
    .run();
  const accessToken = await signJwt(
    { sub: u.id, email: u.email, role: u.role },
    secret,
    ACCESS_TTL,
  );
  const refreshToken = await signJwt({ sub: u.id, jti }, secret, REFRESH_TTL);
  return { accessToken, refreshToken };
}

// ─────────────────────────────── Register ─────────────────────────────────

auth.post('/register', async (c) => {
  if (!c.env.JWT_SECRET) {
    return c.json(fail('SERVER_MISCONFIG', 'کلید امنیتی سرور تنظیم نشده', 'JWT secret missing'), 500);
  }
  const body = await c.req.json<Record<string, any>>().catch(() => null);
  if (!body) return c.json(fail('BAD_REQUEST', 'بدنهٔ درخواست نامعتبر است', 'Invalid body'), 400);

  const role = String(body.role ?? 'student');
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');

  // نام: از firstName/lastName یا fullName.
  let firstName = String(body.firstName ?? '').trim();
  let lastName = String(body.lastName ?? '').trim();
  if (!firstName && body.fullName) {
    const parts = String(body.fullName).trim().split(/\s+/);
    firstName = parts.shift() ?? '';
    lastName = parts.join(' ');
  }

  // اعتبارسنجی پایه (سرور همیشه قطعی — بخش ۴).
  if (!email || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
    return c.json(fail('INVALID_EMAIL', 'ایمیل نامعتبر است', 'Invalid email'), 400);
  }
  if (password.length < 8) {
    return c.json(fail('WEAK_PASSWORD', 'رمز عبور باید حداقل ۸ کاراکتر باشد', 'Password too short'), 400);
  }

  // Invite Code برای دانش‌آموز و استاد اجباری است (بخش ۳ب.۲ / ۲.۲).
  const needsInvite = role === 'student' || role === 'seminar_instructor';
  const inviteType = role === 'seminar_instructor' ? 'instructor' : 'student';
  let inviteRow: { id: string } | null = null;
  if (needsInvite) {
    const code = String(body.inviteCode ?? '').trim();
    inviteRow = await c.env.DB.prepare(
      "SELECT id FROM invite_codes WHERE code = ? AND type = ? AND status = 'unused' " +
        "AND (expires_at IS NULL OR expires_at > datetime('now'))",
    )
      .bind(code, inviteType)
      .first<{ id: string }>();
    // پیام یکسان برای نامعتبر/مصرف‌شده/منقضی (بخش ۳ب.۲.۴ — ضد Enumeration).
    if (!inviteRow) {
      return c.json(fail('INVALID_INVITE_CODE', 'کد دعوت نامعتبر است', 'Invalid invite code'), 403);
    }
  }

  // یکتایی ایمیل.
  const existing = await c.env.DB.prepare('SELECT id FROM users WHERE email = ?')
    .bind(email)
    .first<{ id: string }>();
  if (existing) {
    return c.json(fail('EMAIL_TAKEN', 'این ایمیل قبلاً ثبت شده است', 'Email already registered'), 409);
  }

  const id = uid();
  const passwordHash = await hashPassword(password);
  const currentGrade =
    role === 'student' && body.currentGrade != null ? Number(body.currentGrade) : null;
  const awaitingParentLink = role === 'parent' ? 1 : 0;

  // درج کاربر + مصرف اتمی Invite Code در یک Batch (بخش ۳.۱ مرحلهٔ ۵-۷).
  const statements = [
    c.env.DB.prepare(
      'INSERT INTO users (id, email, password_hash, first_name, last_name, phone, role, status, ' +
        'current_grade, province, date_of_birth, preferred_language, awaiting_parent_link, specialty, bio, email_verified) ' +
        "VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?, ?, ?, ?, ?, ?, ?, 0)",
    ).bind(
      id,
      email,
      passwordHash,
      firstName,
      lastName,
      body.phone ? String(body.phone) : null,
      role,
      currentGrade,
      body.province ? String(body.province) : null,
      body.dateOfBirth ? String(body.dateOfBirth) : null,
      String(body.preferredLanguage ?? 'fa'),
      awaitingParentLink,
      body.specialty ? String(body.specialty) : null,
      body.bio ? String(body.bio) : null,
    ),
  ];
  if (inviteRow) {
    statements.push(
      c.env.DB.prepare(
        "UPDATE invite_codes SET status = 'used', used_by_user_id = ?, used_at = datetime('now') WHERE id = ?",
      ).bind(id, inviteRow.id),
    );
  }
  await c.env.DB.batch(statements);

  const user: UserRow = {
    id,
    email,
    password_hash: passwordHash,
    first_name: firstName,
    last_name: lastName,
    role,
    status: 'active',
    current_grade: currentGrade,
    awaiting_parent_link: awaitingParentLink,
    email_verified: 0,
    avatar_url: null,
  };

  // ارسال لینک تأیید ایمیل — در پس‌زمینه تا پاسخ ثبت‌نام معطل نشود.
  c.executionCtx.waitUntil(
    sendVerificationEmail(c.env, c.req.url, { id, email, first_name: firstName }),
  );

  const tokens = await issueTokens(c.env.DB, c.env.JWT_SECRET, user);
  return c.json({ user: publicUser(user), ...tokens }, 201);
});

// ─────────────────────────── Verify Email ─────────────────────────────────

/** کلیک روی لینک داخل ایمیل — خروجی HTML چون در مرورگر باز می‌شود. */
auth.get('/verify-email', async (c) => {
  const token = c.req.query('token') ?? '';
  if (!token) return c.html(verifyResultPage(false, 'لینک ناقص است'), 400);

  const tokenHash = await sha256B64Url(token);
  const row = await c.env.DB.prepare(
    "SELECT id, user_id FROM email_tokens WHERE token_hash = ? AND type = 'verify' " +
      "AND used = 0 AND expires_at > datetime('now')",
  )
    .bind(tokenHash)
    .first<{ id: string; user_id: string }>();
  if (!row) {
    return c.html(verifyResultPage(false, 'لینک نامعتبر یا منقضی شده است'), 400);
  }

  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE email_tokens SET used = 1 WHERE id = ?').bind(row.id),
    c.env.DB.prepare('UPDATE users SET email_verified = 1 WHERE id = ?').bind(row.user_id),
  ]);
  return c.html(verifyResultPage(true, 'ایمیل شما با موفقیت تأیید شد'));
});

/** ارسال مجدد لینک تأیید — با ایمیل یا با Token (هر دو پذیرفته می‌شود). */
auth.post('/resend-verification', async (c) => {
  let email = '';
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (payload?.['email']) {
    email = String(payload['email']);
  } else {
    const body = await c.req.json<{ email?: string }>().catch(() => null);
    email = String(body?.email ?? '').trim().toLowerCase();
  }
  // پاسخ همیشه یکسان است (ضد Enumeration — بخش ۳.۴ سند).
  const generic = { success: true, message_fa: 'اگر حسابی با این ایمیل باشد، لینک تأیید ارسال شد' };
  if (!email) return c.json(generic);

  const user = await c.env.DB.prepare(
    "SELECT id, email, first_name FROM users WHERE email = ? AND email_verified = 0 AND status = 'active'",
  )
    .bind(email)
    .first<{ id: string; email: string; first_name: string }>();
  if (user) {
    c.executionCtx.waitUntil(sendVerificationEmail(c.env, c.req.url, user));
  }
  return c.json(generic);
});

// ─────────────────────────── Forgot / Reset ───────────────────────────────

/** درخواست بازیابی پسورد — کد ۶ رقمی به ایمیل کاربر فرستاده می‌شود. */
auth.post('/forgot-password', async (c) => {
  const body = await c.req.json<{ email?: string }>().catch(() => null);
  const email = String(body?.email ?? '').trim().toLowerCase();
  // پاسخ همیشه یکسان (ضد Enumeration — بخش ۳.۴ سند).
  const generic = { success: true, message_fa: 'اگر حسابی با این ایمیل باشد، کد بازیابی ارسال شد' };
  if (!email) return c.json(generic);

  const user = await c.env.DB.prepare(
    "SELECT id, email, first_name FROM users WHERE email = ? AND status != 'deleted'",
  )
    .bind(email)
    .first<{ id: string; email: string; first_name: string }>();
  if (!user) return c.json(generic);

  const code = randomSixDigitCode();
  const codeHash = await sha256B64Url(code);
  const expiresAt = new Date(Date.now() + RESET_TTL_MIN * 60_000).toISOString();
  await c.env.DB.batch([
    // کدهای قبلی باطل می‌شوند — فقط آخرین کد معتبر است.
    c.env.DB.prepare("UPDATE email_tokens SET used = 1 WHERE user_id = ? AND type = 'reset'").bind(
      user.id,
    ),
    c.env.DB.prepare(
      "INSERT INTO email_tokens (id, user_id, type, token_hash, expires_at) VALUES (?, ?, 'reset', ?, ?)",
    ).bind(crypto.randomUUID(), user.id, codeHash, expiresAt),
  ]);
  c.executionCtx.waitUntil(
    sendEmail(
      c.env,
      user.email,
      'کد بازیابی رمز عبور — مکتب دیجیتال دختران افغانستان',
      resetEmailHtml(user.first_name, code),
    ),
  );
  return c.json(generic);
});

/** تغییر رمز با کد ۶ رقمی دریافتی در ایمیل. */
auth.post('/reset-password', async (c) => {
  const body = await c.req
    .json<{ email?: string; code?: string; newPassword?: string }>()
    .catch(() => null);
  const email = String(body?.email ?? '').trim().toLowerCase();
  const code = String(body?.code ?? '').trim();
  const newPassword = String(body?.newPassword ?? '');

  if (!email || !/^\d{6}$/.test(code)) {
    return c.json(fail('INVALID_CODE', 'کد بازیابی نامعتبر است', 'Invalid reset code'), 400);
  }
  if (newPassword.length < 8) {
    return c.json(fail('WEAK_PASSWORD', 'رمز عبور باید حداقل ۸ کاراکتر باشد', 'Password too short'), 400);
  }

  const user = await c.env.DB.prepare(
    "SELECT id FROM users WHERE email = ? AND status != 'deleted'",
  )
    .bind(email)
    .first<{ id: string }>();
  if (!user) {
    return c.json(fail('INVALID_CODE', 'کد بازیابی نامعتبر یا منقضی است', 'Invalid or expired code'), 400);
  }

  const row = await c.env.DB.prepare(
    "SELECT id, token_hash, attempts FROM email_tokens WHERE user_id = ? AND type = 'reset' " +
      "AND used = 0 AND expires_at > datetime('now') ORDER BY created_at DESC LIMIT 1",
  )
    .bind(user.id)
    .first<{ id: string; token_hash: string; attempts: number }>();
  if (!row || row.attempts >= RESET_MAX_ATTEMPTS) {
    return c.json(fail('INVALID_CODE', 'کد بازیابی نامعتبر یا منقضی است', 'Invalid or expired code'), 400);
  }

  const codeHash = await sha256B64Url(code);
  if (codeHash !== row.token_hash) {
    await c.env.DB.prepare('UPDATE email_tokens SET attempts = attempts + 1 WHERE id = ?')
      .bind(row.id)
      .run();
    return c.json(fail('INVALID_CODE', 'کد بازیابی نادرست است', 'Wrong reset code'), 400);
  }

  const passwordHash = await hashPassword(newPassword);
  await c.env.DB.batch([
    c.env.DB.prepare('UPDATE email_tokens SET used = 1 WHERE id = ?').bind(row.id),
    c.env.DB.prepare(
      "UPDATE users SET password_hash = ?, email_verified = 1, updated_at = datetime('now') WHERE id = ?",
    ).bind(passwordHash, user.id),
    // امنیت: همهٔ نشست‌های قبلی باطل می‌شوند تا اگر حساب لو رفته بود قطع شود.
    c.env.DB.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?').bind(user.id),
  ]);
  return c.json({ success: true, message_fa: 'رمز عبور با موفقیت تغییر کرد' });
});

// ──────────────────────────────── Login ───────────────────────────────────

auth.post('/login', async (c) => {
  if (!c.env.JWT_SECRET) {
    return c.json(fail('SERVER_MISCONFIG', 'کلید امنیتی سرور تنظیم نشده', 'JWT secret missing'), 500);
  }
  const body = await c.req.json<{ email?: string; password?: string }>().catch(() => null);
  const email = String(body?.email ?? '').trim().toLowerCase();
  const password = String(body?.password ?? '');

  const user = await c.env.DB.prepare('SELECT * FROM users WHERE email = ?')
    .bind(email)
    .first<UserRow>();

  // پیام یکسان برای «ایمیل ناموجود» و «رمز اشتباه» (بخش ۳.۲ — ضد Enumeration).
  if (!user || !(await verifyPassword(password, user.password_hash))) {
    return c.json(fail('INVALID_CREDENTIALS', 'ایمیل یا رمز اشتباه است', 'Invalid email or password'), 401);
  }
  if (user.status === 'suspended' || user.status === 'deleted') {
    return c.json(fail('ACCOUNT_SUSPENDED', 'حساب شما مسدود شده است', 'Account suspended'), 403);
  }

  const tokens = await issueTokens(c.env.DB, c.env.JWT_SECRET, user);
  return c.json({ user: publicUser(user), ...tokens });
});

// ─────────────────────────────── Refresh ──────────────────────────────────

auth.post('/refresh', async (c) => {
  const body = await c.req.json<{ refreshToken?: string }>().catch(() => null);
  const token = String(body?.refreshToken ?? '');
  const payload = await verifyJwt(token, c.env.JWT_SECRET);
  const jti = payload?.['jti'] as string | undefined;
  const sub = payload?.['sub'] as string | undefined;
  if (!payload || !jti || !sub) {
    return c.json(fail('INVALID_TOKEN', 'نشست نامعتبر است', 'Invalid refresh token'), 401);
  }

  const row = await c.env.DB.prepare(
    "SELECT id FROM refresh_tokens WHERE id = ? AND user_id = ? AND revoked = 0 AND expires_at > datetime('now')",
  )
    .bind(jti, sub)
    .first<{ id: string }>();
  if (!row) {
    return c.json(fail('INVALID_TOKEN', 'نشست منقضی شده است', 'Refresh token expired/revoked'), 401);
  }

  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?')
    .bind(sub)
    .first<UserRow>();
  if (!user || user.status !== 'active') {
    return c.json(fail('ACCOUNT_SUSPENDED', 'حساب فعال نیست', 'Account not active'), 403);
  }

  // Rotation: Refresh قدیمی باطل و یک جفت جدید صادر می‌شود (بخش ۳.۳).
  await c.env.DB.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE id = ?').bind(jti).run();
  const tokens = await issueTokens(c.env.DB, c.env.JWT_SECRET, user);
  return c.json({ user: publicUser(user), ...tokens });
});

// ──────────────────────────────── Logout ──────────────────────────────────

auth.post('/logout', async (c) => {
  const body = await c.req.json<{ refreshToken?: string }>().catch(() => null);
  if (body?.refreshToken) {
    const payload = await verifyJwt(body.refreshToken, c.env.JWT_SECRET);
    const jti = payload?.['jti'] as string | undefined;
    if (jti) {
      await c.env.DB.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE id = ?').bind(jti).run();
    }
  }
  return c.json({ success: true });
});

// ────────────────────────────────── Me ────────────────────────────────────

auth.get('/me', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const sub = payload?.['sub'] as string | undefined;
  if (!sub) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?')
    .bind(sub)
    .first<UserRow>();
  if (!user) return c.json(fail('UNAUTHORIZED', 'کاربر یافت نشد', 'User not found'), 401);
  return c.json({ user: publicUser(user) });
});

export default auth;
