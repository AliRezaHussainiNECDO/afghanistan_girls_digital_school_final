/**
 * lib/email.ts — ارسال ایمیل تراکنشی (تأیید ایمیل + بازیابی پسورد) با Resend.
 *
 * چرا Resend؟ Cloudflare Workers نمی‌تواند مستقیم SMTP بفرستد؛ Resend یک
 * API ساده روی HTTPS دارد و پلن رایگان آن (۱۰۰ ایمیل/روز) برای این پروژه
 * کافی است. تنظیم:
 *   ۱) در https://resend.com ثبت‌نام کنید و دامنهٔ
 *      afghanistangirlsdigitalschool.org را Verify کنید.
 *   ۲) کلید API را به‌صورت راز بگذارید:
 *        wrangler secret put RESEND_API_KEY
 *   ۳) (اختیاری) فرستنده را در wrangler.toml تغییر دهید:
 *        EMAIL_FROM = "مکتب دیجیتال <no-reply@afghanistangirlsdigitalschool.org>"
 *
 * اگر RESEND_API_KEY تنظیم نشده باشد، ایمیل واقعی فرستاده نمی‌شود و متن آن
 * فقط در لاگ Worker (wrangler tail) چاپ می‌شود — برای تست محلی کافی است.
 */

export interface EmailEnv {
  RESEND_API_KEY?: string;
  EMAIL_FROM?: string;
}

const DEFAULT_FROM =
  'مکتب دیجیتال دختران افغانستان <no-reply@afghanistangirlsdigitalschool.org>';

/** ارسال یک ایمیل HTML. خروجی: true = ارسال موفق (یا لاگ‌شده در حالت تست). */
export async function sendEmail(
  env: EmailEnv,
  to: string,
  subject: string,
  html: string,
): Promise<boolean> {
  if (!env.RESEND_API_KEY) {
    // حالت تست — بدون کلید، فقط لاگ (در Production کلید را حتماً بگذارید).
    console.log(`[email:test-mode] to=${to} subject=${subject}\n${html}`);
    return true;
  }
  try {
    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${env.RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ from: env.EMAIL_FROM ?? DEFAULT_FROM, to: [to], subject, html }),
    });
    if (!res.ok) {
      console.error(`[email] Resend error ${res.status}: ${await res.text()}`);
      return false;
    }
    return true;
  } catch (e) {
    console.error('[email] send failed:', e);
    return false;
  }
}

/** قالب مشترک ایمیل‌ها — راست‌به‌چپ و ساده تا در همهٔ کلاینت‌ها درست دیده شود. */
function emailShell(title: string, bodyHtml: string): string {
  return `<!doctype html>
<html dir="rtl" lang="fa">
<body style="margin:0;padding:0;background:#f4f6f8;font-family:Tahoma,'Segoe UI',sans-serif;">
  <div style="max-width:520px;margin:24px auto;background:#ffffff;border-radius:12px;overflow:hidden;border:1px solid #e3e8ee;">
    <div style="background:#1b6e4b;color:#ffffff;padding:20px 24px;">
      <div style="font-size:18px;font-weight:bold;">مکتب دیجیتال دختران افغانستان</div>
      <div style="font-size:13px;opacity:.85;margin-top:4px;">${title}</div>
    </div>
    <div style="padding:24px;color:#22303c;font-size:14px;line-height:2;">${bodyHtml}</div>
    <div style="padding:14px 24px;background:#f4f6f8;color:#7b8794;font-size:11px;">
      اگر شما این درخواست را نداده‌اید، این ایمیل را نادیده بگیرید.
    </div>
  </div>
</body>
</html>`;
}

/** ایمیل «تأیید ایمیل» با لینک تأیید. */
export function verificationEmailHtml(firstName: string, verifyUrl: string): string {
  return emailShell(
    'تأیید آدرس ایمیل',
    `<p>سلام ${firstName || 'کاربر گرامی'}،</p>
     <p>برای فعال‌سازی کامل حساب خود در مکتب دیجیتال، روی دکمهٔ زیر کلیک کنید:</p>
     <p style="text-align:center;margin:24px 0;">
       <a href="${verifyUrl}" style="background:#1b6e4b;color:#ffffff;text-decoration:none;padding:12px 32px;border-radius:8px;font-weight:bold;display:inline-block;">تأیید ایمیل</a>
     </p>
     <p style="font-size:12px;color:#7b8794;">اگر دکمه کار نکرد، این لینک را در مرورگر باز کنید:<br>
     <a href="${verifyUrl}" style="color:#1b6e4b;word-break:break-all;">${verifyUrl}</a></p>
     <p>این لینک تا ۴۸ ساعت اعتبار دارد.</p>`,
  );
}

/** ایمیل «بازیابی پسورد» با کد ۶ رقمی. */
export function resetEmailHtml(firstName: string, code: string): string {
  return emailShell(
    'بازیابی رمز عبور',
    `<p>سلام ${firstName || 'کاربر گرامی'}،</p>
     <p>کد بازیابی رمز عبور شما:</p>
     <p style="text-align:center;margin:24px 0;">
       <span style="display:inline-block;background:#f0f7f3;border:1px dashed #1b6e4b;color:#1b6e4b;font-size:28px;letter-spacing:8px;font-weight:bold;padding:12px 24px;border-radius:8px;direction:ltr;">${code}</span>
     </p>
     <p>این کد را در اپلیکیشن وارد کنید. کد تا ۱۵ دقیقه اعتبار دارد.</p>`,
  );
}

// ─────────────────────────── توکن و هش کمکی ────────────────────────────────

/** SHA-256 یک رشته به Base64Url — برای ذخیرهٔ امن توکن/کد در دیتابیس. */
export async function sha256B64Url(input: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(input));
  const bytes = new Uint8Array(digest);
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** توکن تصادفی امن (Base64Url، ~43 کاراکتر) برای لینک تأیید ایمیل. */
export function randomToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

/** کد ۶ رقمی تصادفی امن برای بازیابی پسورد. */
export function randomSixDigitCode(): string {
  const n = crypto.getRandomValues(new Uint32Array(1))[0] % 1_000_000;
  return n.toString().padStart(6, '0');
}
