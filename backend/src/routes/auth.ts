/**
 * routes/auth.ts — روتر احراز هویت (بخش ۳ و ۱۹.۱ سند).
 *
 * Endpointها (زیر `/api/v1/auth`):
 *  POST   /register              ثبت‌نام با بررسی Invite Code + هش رمز + صدور JWT
 *  POST   /login                 تأیید ایمیل/رمز + صدور JWT
 *  POST   /refresh                تمدید Access Token با Refresh Token (Rotation)
 *  POST   /logout                 ابطال Refresh Token
 *  GET    /me                    کاربر فعلی از روی Access Token
 *  PATCH  /me                    ویرایش نام کاربر فعلی (رفع اشکال: قبلاً فقط محلی بود)
 *  POST   /change-password        تغییر رمز با رمز فعلی، کاربرِ واردشده (رفع اشکال: قبلاً ساختگی بود)
 *  GET    /verify-email           تأیید ایمیل با توکن لینک (صفحهٔ HTML)
 *  POST   /resend-verification    ارسال مجدد لینک تأیید ایمیل
 *  POST   /forgot-password        ارسال کد ۶ رقمی بازیابی به ایمیل
 *  POST   /reset-password          تغییر رمز با کد ۶ رقمی
 */
import { Hono } from 'hono';
import { hashPassword, verifyPassword, signJwt, verifyJwt, verifyBearer } from '../lib/auth';
import { logAudit, clientIp } from '../lib/audit';
import { hitRateLimit, rateLimitFail } from '../lib/rateLimit';
import {
  sendEmail,
  verificationEmailHtml,
  resetEmailHtml,
  sha256B64Url,
  randomToken,
  randomSixDigitCode,
} from '../lib/email';
import { sendPushToUsers } from '../lib/push';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  RESEND_API_KEY?: string;
  EMAIL_FROM?: string;
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
};

const ACCESS_TTL = 60 * 15; // ۱۵ دقیقه (بخش ۳.۳)
const REFRESH_TTL = 60 * 60 * 24 * 30; // ۳۰ روز

const auth = new Hono<{ Bindings: Bindings }>();

const uid = () => crypto.randomUUID();

/** پاسخ خطای استاندارد مطابق قرارداد بخش ۱۹.۱۰ سند. */
function fail(code: string, messageFa: string, messageEn: string, messagePs?: string, messageFr?: string) {
  return { success: false, error: { code, message_fa: messageFa, message_en: messageEn, message_ps: messagePs ?? messageEn, message_fr: messageFr ?? messageEn } };
}

/**
 * نرمال‌سازی کد دعوت پیش از مقایسه: حذف فاصله‌های اضافه، حروف بزرگ، و
 * تبدیل ارقام فارسی/عربی به لاتین — تا مقایسهٔ دقیق سرور با کدهایی که
 * کاربر با فاصله/حروف کوچک/ارقام فارسی تایپ کرده هم درست کار کند.
 */
function normalizeInviteCode(raw: string): string {
  const fa = '۰۱۲۳۴۵۶۷۸۹';
  const ar = '٠١٢٣٤٥٦٧٨٩';
  let out = '';
  for (const ch of raw.trim().toUpperCase()) {
    const iFa = fa.indexOf(ch);
    const iAr = ar.indexOf(ch);
    if (iFa >= 0) out += String(iFa);
    else if (iAr >= 0) out += String(iAr);
    else if (ch !== ' ') out += ch;
  }
  return out;
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
  // همان رفع اشکال Rate Limiting بالا — اینجا مهم‌تر است چون این Endpoint
  // مسیر حدسِ خودکار «کد دعوت» (`inviteCode`) هم هست؛ حداکثر ۸ تلاش در هر
  // ساعت به‌ازای هر IP (بازهٔ طولانی‌تر و سقف پایین‌تر از login چون ثبت‌نام
  // واقعی به‌ندرت بیش از یکی-دو بار در ساعت از یک آدرس اتفاق می‌افتد).
  const registerIp = clientIp(c) ?? 'unknown';
  const registerRl = await hitRateLimit(c.env.DB, `register:${registerIp}`, 60 * 60, 8);
  if (registerRl.limited) return c.json(rateLimitFail(), 429);

  if (!c.env.JWT_SECRET) {
    return c.json(fail('SERVER_MISCONFIG', 'کلید امنیتی سرور تنظیم نشده', 'JWT secret missing', 'د سرور امنیتي کیلي تنظیم شوې نه ده', 'La clé de sécurité du serveur n\'est pas configurée'), 500);
  }
  const body = await c.req.json<Record<string, any>>().catch(() => null);
  if (!body) return c.json(fail('BAD_REQUEST', 'بدنهٔ درخواست نامعتبر است', 'Invalid body', 'د غوښتنې متن ناسم دی', 'Le corps de la requête est invalide'), 400);

  const role = String(body.role ?? 'student');
  const email = String(body.email ?? '').trim().toLowerCase();
  const password = String(body.password ?? '');

  // رفع اشکال امنیتی حیاتی: قبلاً «role» بدون هیچ محدودیتی از بدنهٔ درخواست
  // پذیرفته می‌شد — یعنی هر کاربر ناشناس می‌توانست با ارسال
  // `{"role":"super_admin"}` مستقیماً یک حساب مدیر کل بسازد (چون نیاز به
  // Invite Code فقط برای student/seminar_instructor بررسی می‌شد، نه برای
  // بقیهٔ نقش‌ها). ثبت‌نام عمومی فقط باید به نقش‌های غیرحساس اجازه دهد؛
  // super_admin هرگز نباید از این Endpoint قابل‌دستیابی باشد (فقط با
  // migrations/0012_super_admin.sql یا توسط مدیر دیگر ساخته می‌شود).
  const PUBLIC_REGISTRABLE_ROLES = new Set(['student', 'parent', 'seminar_instructor']);
  if (!PUBLIC_REGISTRABLE_ROLES.has(role)) {
    return c.json(fail('INVALID_ROLE', 'نقش انتخاب‌شده معتبر نیست', 'Invalid role', 'ټاکل شوی رول معتبر نه دی', 'Le rôle sélectionné est invalide'), 400);
  }

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
    return c.json(fail('INVALID_EMAIL', 'ایمیل نامعتبر است', 'Invalid email', 'بریښنالیک نامعتبر دی', 'E-mail invalide'), 400);
  }
  if (password.length < 8) {
    return c.json(fail('WEAK_PASSWORD', 'رمز عبور باید حداقل ۸ کاراکتر باشد', 'Password too short', 'پټنوم باید لږترلږه ۸ توري ولري', 'Le mot de passe doit comporter au moins 8 caractères'), 400);
  }

  // Invite Code برای دانش‌آموز و استاد اجباری است (بخش ۳ب.۲ / ۲.۲).
  const needsInvite = role === 'student' || role === 'seminar_instructor';
  const inviteType = role === 'seminar_instructor' ? 'instructor' : 'student';
  let inviteRow: { id: string } | null = null;
  if (needsInvite) {
    // رفع اشکال: مقایسهٔ کد در SQLite به‌طور پیش‌فرض حساس به بزرگی/کوچکی حروف
    // است، اما کدها همیشه با حروف بزرگ ساخته می‌شوند (`TCH-XXXXXX`/
    // `STU-XXXXXX`)؛ اگر کاربر آن را با حروف کوچک یا با فاصلهٔ اضافه تایپ
    // کند، مقایسهٔ دقیق شکست می‌خورد و پیام «کد نامعتبر» به‌اشتباه نمایش
    // داده می‌شود. اینجا همان نرمال‌سازی‌ای که قبلاً فقط سمت کلاینت (محلی)
    // انجام می‌شد را روی سرور هم اعمال می‌کنیم.
    const code = normalizeInviteCode(String(body.inviteCode ?? ''));
    inviteRow = await c.env.DB.prepare(
      "SELECT id FROM invite_codes WHERE code = ? AND type = ? AND status = 'unused' " +
        "AND (expires_at IS NULL OR expires_at > datetime('now'))",
    )
      .bind(code, inviteType)
      .first<{ id: string }>();
    // پیام یکسان برای نامعتبر/مصرف‌شده/منقضی (بخش ۳ب.۲.۴ — ضد Enumeration).
    if (!inviteRow) {
      return c.json(fail('INVALID_INVITE_CODE', 'کد دعوت نامعتبر است', 'Invalid invite code', 'د بلنې کوډ نامعتبر دی', 'Code d\'invitation invalide'), 403);
    }
  }

  // یکتایی ایمیل.
  const existing = await c.env.DB.prepare('SELECT id FROM users WHERE email = ?')
    .bind(email)
    .first<{ id: string }>();
  if (existing) {
    return c.json(fail('EMAIL_TAKEN', 'این ایمیل قبلاً ثبت شده است', 'Email already registered', 'دا بریښنالیک دمخه ثبت شوی دی', 'Cette adresse e-mail est déjà enregistrée'), 409);
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

  // اعلان ثبت‌نام تازه به همهٔ مدیران — بخش «اعلان‌های داشبورد مدیر» (رفع
  // اشکال هماهنگی: قبلاً هیچ فعالیت جدیدی در بخش کاربران/مدیریت باعث اعلان
  // نمی‌شد؛ مدیر فقط با رجوع دستی به فهرست کاربران می‌فهمید کسی ثبت‌نام
  // کرده). طبق منطق داشبورد مدیر: کاربر تازه = رویدادی که باید فوراً دیده
  // شود، دقیقاً مثل پیام‌های حساسِ ایمنی که همین الگو را دارند.
  const roleLabelFa = role === 'seminar_instructor' ? 'استاد' : role === 'parent' ? 'والد' : 'دانش‌آموز';
  const fullNameFa = `${firstName} ${lastName}`.trim() || email;
  const { results: adminsForNotice } = await c.env.DB.prepare(
    "SELECT id FROM users WHERE role = 'super_admin'",
  ).all<{ id: string }>();
  // kind='account' (نه 'general') + related_id به‌صورت `role:userId` تا
  // کلاینت بداند لمس این اعلان باید کدام صفحهٔ جزئیات مدیر (شاگرد/استاد/
  // والد) را باز کند.
  for (const admin of adminsForNotice) {
    statements.push(
      c.env.DB.prepare(
        "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind, related_id) VALUES (?, ?, ?, ?, 'medium', 'account', ?)",
      ).bind(
        uid(),
        admin.id,
        'ثبت‌نام کاربر جدید 👋',
        `«${fullNameFa}» به‌عنوان ${roleLabelFa} در برنامه ثبت‌نام کرد.`,
        `${role}:${id}`,
      ),
    );
  }

  await c.env.DB.batch(statements);
  if (adminsForNotice.length > 0) {
    c.executionCtx.waitUntil(
      sendPushToUsers(
        c.env,
        adminsForNotice.map((a) => a.id),
        'ثبت‌نام کاربر جدید 👋',
        `«${fullNameFa}» به‌عنوان ${roleLabelFa} در برنامه ثبت‌نام کرد.`,
      ),
    );
  }

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

  // Auditability (بخش ۲۰.۳): ثبت‌نام کاربر + مصرف کد دعوت (بخش ۳ب.۳).
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: id,
      actorRole: role,
      actionType: 'user_register',
      targetTable: 'users',
      targetId: id,
      ipAddress: clientIp(c),
      detail: { role, inviteCodeId: inviteRow?.id ?? null, currentGrade },
    }),
  );

  const tokens = await issueTokens(c.env.DB, c.env.JWT_SECRET, user);
  return c.json({ user: publicUser(user), ...tokens }, 201);
});

// ─────────────────────────── Verify Email ─────────────────────────────────

/**
 * کلیک روی لینک داخل ایمیل — خروجی HTML چون در مرورگر باز می‌شود.
 *
 * نکتهٔ مهم (رفع اشکال): بعضی از اپلیکیشن‌های ایمیل (Apple Mail Privacy
 * Protection، پیش‌نمایش لینک در Safari/iMessage، اسکنرهای امنیتی شرکتی و
 * غیره) به‌صورت خودکار همین URL را در پس‌زمینه بارگذاری می‌کنند تا پیش‌نمایش
 * بسازند — این یعنی توکن یک‌بارمصرف ممکن است قبل از کلیک واقعی کاربر مصرف
 * شده باشد. برای جلوگیری از نمایش گمراه‌کنندهٔ «لینک نامعتبر» در این حالت،
 * ابتدا بررسی می‌کنیم که آیا ایمیل کاربر از قبل تأیید شده — اگر بله، نتیجه
 * را «موفق» نشان می‌دهیم (Idempotent) حتی اگر همین توکن قبلاً مصرف شده باشد.
 */
auth.get('/verify-email', async (c) => {
  const token = c.req.query('token') ?? '';
  if (!token) return c.html(verifyResultPage(false, 'لینک ناقص است'), 400);

  const tokenHash = await sha256B64Url(token);
  // در WHERE عمداً روی «used = 0» فیلتر نمی‌کنیم تا بتوانیم بین «توکن اصلاً
  // وجود ندارد» و «توکن قبلاً مصرف شده» تمایز قائل شویم.
  const row = await c.env.DB.prepare(
    "SELECT id, user_id, used, expires_at FROM email_tokens WHERE token_hash = ? AND type = 'verify'",
  )
    .bind(tokenHash)
    .first<{ id: string; user_id: string; used: number; expires_at: string }>();

  if (!row) {
    return c.html(verifyResultPage(false, 'لینک نامعتبر یا منقضی شده است'), 400);
  }

  const user = await c.env.DB.prepare('SELECT email_verified FROM users WHERE id = ?')
    .bind(row.user_id)
    .first<{ email_verified: number }>();
  if (user?.email_verified === 1) {
    // احتمالاً پیش‌بارگذاری خودکار همین لینک قبلاً ایمیل را تأیید کرده —
    // نتیجه را موفق نشان بده تا کاربر واقعی با خطای کاذب مواجه نشود.
    return c.html(verifyResultPage(true, 'ایمیل شما با موفقیت تأیید شد'));
  }

  const expired = new Date(row.expires_at).getTime() <= Date.now();
  if (row.used === 1 || expired) {
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
  // Rate limit — جلوگیری از هرزنامهٔ ایمیل (Email bombing) با فراخوانی مکرر
  // این Endpoint برای یک یا چند ایمیل از یک آدرس.
  const forgotIp = clientIp(c) ?? 'unknown';
  const forgotRl = await hitRateLimit(c.env.DB, `forgot:${forgotIp}`, 60 * 60, 5);
  if (forgotRl.limited) return c.json(rateLimitFail(), 429);

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

  // Rate limit — کد بازیابی فقط ۶ رقمی است (۱ میلیون حالت)؛ بدون این محدودیت
  // یک مهاجم که ایمیل قربانی را می‌داند می‌توانست با حدس خودکار کد را پیدا
  // کند. هم به‌ازای IP و هم به‌ازای همان ایمیل هدف محدود می‌شود.
  const resetIp = clientIp(c) ?? 'unknown';
  const resetIpRl = await hitRateLimit(c.env.DB, `reset-ip:${resetIp}`, 15 * 60, 10);
  const resetEmailRl = email
    ? await hitRateLimit(c.env.DB, `reset-email:${email}`, 15 * 60, 8)
    : { limited: false };
  if (resetIpRl.limited || resetEmailRl.limited) return c.json(rateLimitFail(), 429);

  if (!email || !/^\d{6}$/.test(code)) {
    return c.json(fail('INVALID_CODE', 'کد بازیابی نامعتبر است', 'Invalid reset code', 'د بیارغونې کوډ نامعتبر دی', 'Code de réinitialisation invalide'), 400);
  }
  if (newPassword.length < 8) {
    return c.json(fail('WEAK_PASSWORD', 'رمز عبور باید حداقل ۸ کاراکتر باشد', 'Password too short', 'پټنوم باید لږترلږه ۸ توري ولري', 'Le mot de passe doit comporter au moins 8 caractères'), 400);
  }

  const user = await c.env.DB.prepare(
    "SELECT id FROM users WHERE email = ? AND status != 'deleted'",
  )
    .bind(email)
    .first<{ id: string }>();
  if (!user) {
    return c.json(fail('INVALID_CODE', 'کد بازیابی نامعتبر یا منقضی است', 'Invalid or expired code', 'د بیارغونې کوډ نامعتبر یا پای ته رسیدلی دی', 'Code invalide ou expiré'), 400);
  }

  const row = await c.env.DB.prepare(
    "SELECT id, token_hash, attempts FROM email_tokens WHERE user_id = ? AND type = 'reset' " +
      "AND used = 0 AND expires_at > datetime('now') ORDER BY created_at DESC LIMIT 1",
  )
    .bind(user.id)
    .first<{ id: string; token_hash: string; attempts: number }>();
  if (!row || row.attempts >= RESET_MAX_ATTEMPTS) {
    return c.json(fail('INVALID_CODE', 'کد بازیابی نامعتبر یا منقضی است', 'Invalid or expired code', 'د بیارغونې کوډ نامعتبر یا پای ته رسیدلی دی', 'Code invalide ou expiré'), 400);
  }

  const codeHash = await sha256B64Url(code);
  if (codeHash !== row.token_hash) {
    await c.env.DB.prepare('UPDATE email_tokens SET attempts = attempts + 1 WHERE id = ?')
      .bind(row.id)
      .run();
    return c.json(fail('INVALID_CODE', 'کد بازیابی نادرست است', 'Wrong reset code', 'د بیارغونې کوډ ناسم دی', 'Code de réinitialisation incorrect'), 400);
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
  // رفع اشکال امنیتی «آمادگی انتشار»: قبلاً هیچ Rate Limiting روی ورود نبود
  // — تلاش‌های ناموفق فقط در audit_logs لاگ می‌شدند ولی هیچ قفل موقتی اعمال
  // نمی‌شد، یعنی حدس رمز به‌صورت خودکار (Brute-force) محدودیتی نداشت. حالا
  // حداکثر ۱۲ تلاش (موفق یا ناموفق) در هر ۱۵ دقیقه به‌ازای هر IP مجاز است.
  const loginIp = clientIp(c) ?? 'unknown';
  const loginRl = await hitRateLimit(c.env.DB, `login:${loginIp}`, 15 * 60, 12);
  if (loginRl.limited) return c.json(rateLimitFail(), 429);

  if (!c.env.JWT_SECRET) {
    return c.json(fail('SERVER_MISCONFIG', 'کلید امنیتی سرور تنظیم نشده', 'JWT secret missing', 'د سرور امنیتي کیلي تنظیم شوې نه ده', 'La clé de sécurité du serveur n\'est pas configurée'), 500);
  }
  const body = await c.req.json<{ email?: string; password?: string }>().catch(() => null);
  const email = String(body?.email ?? '').trim().toLowerCase();
  const password = String(body?.password ?? '');

  const user = await c.env.DB.prepare('SELECT * FROM users WHERE email = ?')
    .bind(email)
    .first<UserRow>();

  // پیام یکسان برای «ایمیل ناموجود» و «رمز اشتباه» (بخش ۳.۲ — ضد Enumeration).
  if (!user || !(await verifyPassword(password, user.password_hash))) {
    // Auditability (بخش ۲۰.۳): ورود ناموفق (موفق و ناموفق هر دو ثبت می‌شوند).
    c.executionCtx.waitUntil(
      logAudit(c.env.DB, {
        actorId: user?.id ?? null,
        actionType: 'login_failed',
        targetTable: 'users',
        targetId: user?.id ?? null,
        ipAddress: clientIp(c),
        detail: { email },
      }),
    );
    return c.json(fail('INVALID_CREDENTIALS', 'ایمیل یا رمز اشتباه است', 'Invalid email or password', 'بریښنالیک یا پټنوم ناسم دی', 'E-mail ou mot de passe incorrect'), 401);
  }
  if (user.status === 'suspended' || user.status === 'deleted') {
    c.executionCtx.waitUntil(
      logAudit(c.env.DB, {
        actorId: user.id,
        actorRole: user.role,
        actionType: 'login_blocked',
        targetTable: 'users',
        targetId: user.id,
        ipAddress: clientIp(c),
        detail: { status: user.status },
      }),
    );
    return c.json(fail('ACCOUNT_SUSPENDED', 'حساب شما مسدود شده است', 'Account suspended', 'ستاسو حساب بند شوی دی', 'Votre compte a été suspendu'), 403);
  }

  const tokens = await issueTokens(c.env.DB, c.env.JWT_SECRET, user);
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: user.id,
      actorRole: user.role,
      actionType: 'login_success',
      targetTable: 'users',
      targetId: user.id,
      ipAddress: clientIp(c),
    }),
  );
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
    return c.json(fail('INVALID_TOKEN', 'نشست نامعتبر است', 'Invalid refresh token', 'ناسته نامعتبره ده', 'Session invalide'), 401);
  }

  const row = await c.env.DB.prepare(
    "SELECT id FROM refresh_tokens WHERE id = ? AND user_id = ? AND revoked = 0 AND expires_at > datetime('now')",
  )
    .bind(jti, sub)
    .first<{ id: string }>();
  if (!row) {
    return c.json(fail('INVALID_TOKEN', 'نشست منقضی شده است', 'Refresh token expired/revoked', 'ناسته پای ته رسیدلې ده', 'La session a expiré'), 401);
  }

  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?')
    .bind(sub)
    .first<UserRow>();
  if (!user || user.status !== 'active') {
    return c.json(fail('ACCOUNT_SUSPENDED', 'حساب فعال نیست', 'Account not active', 'حساب فعال نه دی', 'Le compte n\'est pas actif'), 403);
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
      // Auditability (بخش ۲۰.۳): خروج نیز مانند ورود ثبت می‌شود.
      c.executionCtx.waitUntil(
        logAudit(c.env.DB, {
          actorId: (payload?.['sub'] as string | undefined) ?? null,
          actionType: 'logout',
          targetTable: 'refresh_tokens',
          targetId: jti,
          ipAddress: clientIp(c),
        }),
      );
    }
  }
  return c.json({ success: true });
});

// ──────────────────────────────────  Me  ────────────────────────────────────

auth.get('/me', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const sub = payload?.['sub'] as string | undefined;
  if (!sub) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?')
    .bind(sub)
    .first<UserRow>();
  if (!user) return c.json(fail('UNAUTHORIZED', 'کاربر یافت نشد', 'User not found', 'کارن ونه موندل شو', 'Utilisateur introuvable'), 401);
  return c.json({ user: publicUser(user) });
});

// رفع اشکال حیاتی: قبلاً دیالوگ «تغییر رمز عبور» در صفحهٔ پروفایل هیچ
// درخواستی به سرور نمی‌فرستاد و فقط پیام «موفق» ساختگی نشان می‌داد — یعنی
// رمز عبور واقعاً هرگز تغییر نمی‌کرد، اما کاربر گمان می‌کرد رمزش عوض شده.
auth.post('/change-password', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const sub = payload?.['sub'] as string | undefined;
  if (!sub) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const b = await c.req.json<{ currentPassword?: string; newPassword?: string }>().catch(() => null);
  const currentPassword = String(b?.currentPassword ?? '');
  const newPassword = String(b?.newPassword ?? '');
  if (newPassword.length < 8) {
    return c.json(fail('WEAK_PASSWORD', 'رمز عبور جدید باید حداقل ۸ کاراکتر باشد', 'Password too short', 'نوی پټنوم باید لږترلږه ۸ توري ولري', 'Le nouveau mot de passe doit comporter au moins 8 caractères'), 400);
  }
  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(sub).first<UserRow>();
  if (!user || !(await verifyPassword(currentPassword, user.password_hash))) {
    return c.json(fail('INVALID_CREDENTIALS', 'رمز عبور فعلی نادرست است', 'Current password is incorrect', 'اوسنی پټنوم ناسم دی', 'Le mot de passe actuel est incorrect'), 401);
  }
  const passwordHash = await hashPassword(newPassword);
  await c.env.DB.batch([
    c.env.DB.prepare("UPDATE users SET password_hash = ?, updated_at = datetime('now') WHERE id = ?")
      .bind(passwordHash, sub),
    // امنیت: همهٔ نشست‌ها (این دستگاه هم) باطل می‌شوند تا کاربر با رمز تازه دوباره وارد شود.
    c.env.DB.prepare('UPDATE refresh_tokens SET revoked = 1 WHERE user_id = ?').bind(sub),
  ]);
  return c.json({ success: true, message_fa: 'رمز عبور با موفقیت تغییر کرد' });
});

// رفع اشکال: قبلاً «ویرایش نام» در صفحهٔ پروفایل فقط `state` محلی نشست را
// تغییر می‌داد (بدون بک‌اند واقعی) — یعنی با ورود مجدد یا در هر داشبورد
// دیگری (فهرست شاگردان مدیر، هم‌صنفی‌های چت، فهرست ثبت‌نامی سمینار و...)
// نام قدیمی همچنان دیده می‌شد. اکنون واقعاً روی جدول `users` ذخیره می‌شود.
auth.patch('/me', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const sub = payload?.['sub'] as string | undefined;
  if (!sub) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const b = await c.req.json<{ firstName?: string; lastName?: string }>().catch(() => null);
  const firstName = String(b?.firstName ?? '').trim();
  const lastName = String(b?.lastName ?? '').trim();
  if (!firstName) {
    return c.json(fail('BAD_REQUEST', 'نام نمی‌تواند خالی باشد', 'Name is required', 'نوم نشي کولی خالي وي', 'Le nom est requis'), 400);
  }
  await c.env.DB.prepare("UPDATE users SET first_name = ?, last_name = ?, updated_at = datetime('now') WHERE id = ?")
    .bind(firstName, lastName, sub)
    .run();
  const user = await c.env.DB.prepare('SELECT * FROM users WHERE id = ?').bind(sub).first<UserRow>();
  if (!user) return c.json(fail('UNAUTHORIZED', 'کاربر یافت نشد', 'User not found', 'کارن ونه موندل شو', 'Utilisateur introuvable'), 401);
  return c.json({ user: publicUser(user) });
});

export default auth;
// (audit wiring v1 — بخش ۲۰.۳)
