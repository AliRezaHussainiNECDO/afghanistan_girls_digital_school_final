/**
 * بک‌اند «مکتب دیجیتال دختران افغانستان» روی Cloudflare Workers (Hono).
 *
 * همهٔ منطق در روترهای ماژولار زیر `src/routes/*` است و اینجا فقط mount
 * می‌شوند. همهٔ مسیرها زیر `/api/v1` (هماهنگ با BASE_URL اپ فلاتر).
 */
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import authRouter from './routes/auth';
import curriculumRouter from './routes/curriculum';
import examsRouter from './routes/exams';
import engagementRouter from './routes/engagement';
import adminRouter from './routes/admin';
import seminarsRouter from './routes/seminars';
import parentsRouter from './routes/parents';
import aiRouter from './routes/ai';
import mediaRouter from './routes/media';
import cmsRouter from './routes/cms';
import memoryRouter from './routes/memory';
import academyRouter from './routes/academy';

type Bindings = {
  DB: D1Database;
  BUCKET: R2Bucket;
  ALLOWED_ORIGIN: string;
  JWT_SECRET: string;
  AI_PROVIDER_KEY?: string;
  AI_PROVIDER_URL?: string;
  AI_MODEL?: string;
  AZURE_TTS_KEY?: string;
  AZURE_TTS_REGION?: string;
  AZURE_TTS_VOICE?: string;
  AI_TTS_URL?: string;
  AI_TTS_MODEL?: string;
  AI_TTS_VOICE?: string;
  AI_STT_URL?: string;
  AI_STT_MODEL?: string;
};

const app = new Hono<{ Bindings: Bindings }>();

app.use('*', async (c, next) => {
  const mw = cors({ origin: c.env.ALLOWED_ORIGIN ?? '*' });
  return mw(c, next);
});

app.get('/', (c) => c.json({ ok: true, service: 'afghan-girls-school-api' }));

// ─────────────────── نگهبان سراسری خطا (Global Error Guard) ───────────────────
// چرا لازم است؟ اگر یک Endpoint به هر دلیلی (مثلاً جدولی که هنوز مهاجرت
// نشده، یا یک استثنای پیش‌بینی‌نشده) استثنا پرتاب کند، بدون این نگهبان
// Cloudflare Workers یک پاسخ ۵۰۰ خامِ غیر-JSON برمی‌گرداند؛ کلاینت (ApiClient)
// نمی‌تواند آن را پارس کند و کاربر فقط «خطای ناشناخته» می‌بیند بدون جزئیات
// قابل پیگیری در لاگ. این نگهبان همیشه یک JSON با قرارداد خطای استاندارد
// برمی‌گرداند و خطای واقعی را در لاگ سرور (wrangler tail) ثبت می‌کند تا
// مشکلات مثل «جدول/ستون مهاجرت‌نشده» سریع قابل تشخیص باشند.
app.onError((err, c) => {
  console.error(`[unhandled] ${c.req.method} ${c.req.path} →`, err);
  return c.json(
    {
      success: false,
      error: {
        code: 'INTERNAL_ERROR',
        message_fa: 'خطای داخلی سرور رخ داد. لطفاً کمی بعد دوباره تلاش کنید.',
        message_en: 'An internal server error occurred. Please try again shortly.',
      },
    },
    500,
  );
});

app.notFound((c) =>
  c.json(
    {
      success: false,
      error: {
        code: 'NOT_FOUND',
        message_fa: 'این مسیر روی سرور یافت نشد.',
        message_en: 'This endpoint was not found on the server.',
      },
    },
    404,
  ),
);

// ───────────────────────────── احراز هویت ─────────────────────────────
app.route('/api/v1/auth', authRouter);

// ───────────────────────────── نصاب و پیشرفت ─────────────────────────────
app.route('/api/v1', curriculumRouter);

// ─────────────────────── امتحانات، نمرات و گواهی‌نامه ───────────────────────
app.route('/api/v1', examsRouter);

// ───────────────────────────── حاضری و اعلان‌ها ─────────────────────────────
app.route('/api/v1', engagementRouter);

// ───────────────────── مدیریت کاربران/کدهای دعوت (فقط مدیر) ─────────────────
app.route('/api/v1/admin', adminRouter);

// ─────────────────────────────── سمینارها ──────────────────────────────────
app.route('/api/v1', seminarsRouter);

// ───────────────────── پیوند والد-فرزند و داشبورد والد ──────────────────────
app.route('/api/v1', parentsRouter);

// ───────────────────────── معلم هوشمند (LLM proxy) ─────────────────────────
app.route('/api/v1', aiRouter);

// ───────────── چت (متن/صوت)، کتابخانهٔ PDF، فایل‌ها روی R2، رضایت‌نامه ────────
app.route('/api/v1', mediaRouter);

// ───────────────────────── تألیف محتوای مدیر (CMS) ─────────────────────────
app.route('/api/v1/admin/cms', cmsRouter);

// ─────────────────────────── حافظهٔ جمعی (فید اجتماعی) ──────────────────────
app.route('/api/v1', memoryRouter);

// ─────────────────────── آکادمی (کتابخانه/بانک سؤال/پاسخ‌ها) ────────────────
app.route('/api/v1', academyRouter);

export default app;
