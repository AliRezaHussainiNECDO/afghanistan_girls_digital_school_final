/**
 * بک‌اند «مکتب دیجیتال دختران افغانستان» روی Cloudflare Workers (Hono).
 *
 * همهٔ منطق در روترهای ماژولار زیر `src/routes/*` است و اینجا فقط mount
 * می‌شوند. همهٔ مسیرها زیر `/api/v1` (هماهنگ با BASE_URL اپ فلاتر).
 */
import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { verifyBearer } from './lib/auth';
import authRouter from './routes/auth';
import curriculumRouter from './routes/curriculum';
import examsRouter, { verifyCertificateHandler } from './routes/exams';
import { privacyPolicyHandler } from './routes/privacy';
import engagementRouter from './routes/engagement';
import adminRouter from './routes/admin';
import seminarsRouter from './routes/seminars';
import parentsRouter from './routes/parents';
import aiRouter from './routes/ai';
import mediaRouter from './routes/media';
import memoryRouter from './routes/memory';
import academyRouter from './routes/academy';
import advisorRouter from './routes/advisor';
import homeworkRouter from './routes/homework';
import devicesRouter from './routes/devices';
import aiCurriculumRouter from './routes/aiCurriculum';
import chapterQuizzesRouter from './routes/chapterQuizzes';
import finalExamsRouter from './routes/finalExams';
import errorLogsRouter from './routes/errorLogs';
import competitionRouter from './routes/competition';
import liveArenaRouter from './routes/liveArena';
export { LiveArenaRoom } from './lib/liveArenaRoom';
import { transitionArenaEvents } from './lib/liveArena';
import { captureError } from './lib/errorLog';
import { notifyFinalExamRetakesDue } from './lib/finalExamRetakeNotify';

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
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
  GEMINI_IMAGE_MODEL?: string;
  // ── Push Notification واقعی (FCM HTTP v1) — lib/push.ts. همه اختیاری‌اند؛
  //    در نبودشان اعلان‌ها فقط داخل‌اپی (زنگ 🔔) می‌مانند، بدون کرش/تأخیر.
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
  // «آرنای زنده» — Durable Object یک اتاق زنده به‌ازای هر رویداد هفتگی
  // (نگاه کن به lib/liveArenaRoom.ts + wrangler.toml [[durable_objects.bindings]]).
  LIVE_ARENA_ROOM: DurableObjectNamespace;
};

const app = new Hono<{ Bindings: Bindings }>();

app.use('*', async (c, next) => {
  // `ALLOWED_ORIGIN` می‌تواند چند دامنه با کاما جدا شده باشد (مثلاً نسخهٔ
  // http/https یا با/بدون www) — اینجا به فهرست تبدیل می‌شود تا Hono دقیقاً
  // همان Originهای مجاز را بپذیرد. "*" هم هنوز پشتیبانی می‌شود (برای توسعهٔ
  // محلی)، اما دیگر مقدار پیش‌فرض نیست.
  const raw = c.env.ALLOWED_ORIGIN ?? '*';
  const origin = raw === '*' ? '*' : raw.split(',').map((o) => o.trim()).filter(Boolean);
  const mw = cors({ origin });
  return mw(c, next);
});

app.get('/', (c) => c.json({ ok: true, service: 'afghan-girls-school-api' }));

// ─────────── تأیید عمومی اصالت گواهی‌نامه — روی ریشهٔ دامنهٔ برند ───────────
// همان Handler که زیر `/api/v1/certificates/verify/:serial` هم هست (سازگاری
// با نسخه‌های قبلی)، این‌جا مستقیماً روی `/verify/:serial` هم mount شده تا
// وقتی Route دامنهٔ afghanistangirlsdigitalschool.org فعال شود، آدرس روی QR
// همان آدرس کوتاه و برندشدهٔ خواسته‌شده باشد:
// afghanistangirlsdigitalschool.org/verify/AGDS-... — نه یک آدرس فنی زیر
// api./workers.dev. عمداً بیرون از `/api/v1/*` است چون یک صفحهٔ HTML عمومیِ
// بدون نیاز به ورود است، نه یک Endpoint JSON.
app.get('/verify/:serial', verifyCertificateHandler);

// ─────────── سیاست حریم خصوصی و قوانین استفاده — روی ریشهٔ دامنهٔ برند ───────────
// همان الگوی /verify بالا: یک صفحهٔ HTML عمومیِ همیشه‌در‌دسترس (بدون نیاز به
// دیتابیس یا ورود) که Google Play/App Store به‌عنوان Privacy Policy URL در
// Store Listing می‌خواهند. متن دقیقاً همان متن تأییدشدهٔ داخل اپ (Flutter
// terms_gate.dart) است.
app.get('/privacy', privacyPolicyHandler);

// ─────────────────── ضربان حضور (Presence Heartbeat) ────────────────────────
// هر درخواستِ دارای توکن معتبر، `users.last_seen_at` را در پس‌زمینه تازه
// می‌کند (migration 0032) — بدون هیچ تأخیری در پاسخ اصلی (waitUntil بعد از
// next اجرا می‌شود). مبنای «کاربران آنلاین» در داشبورد زندهٔ مدیر
// (GET /admin/dashboard/live). کاملاً fail-safe: هر خطایی بی‌صدا نادیده
// گرفته می‌شود تا هرگز مسیر اصلی را نشکند.
app.use('/api/v1/*', async (c, next) => {
  await next();
  const authHeader = c.req.header('Authorization');
  if (authHeader?.startsWith('Bearer ')) {
    c.executionCtx.waitUntil(
      (async () => {
        try {
          const p = await verifyBearer(authHeader, c.env.JWT_SECRET);
          const sub = p?.['sub'] as string | undefined;
          if (sub) {
            await c.env.DB.prepare("UPDATE users SET last_seen_at=datetime('now') WHERE id=?")
              .bind(sub)
              .run();
          }
        } catch {
          /* بی‌صدا — ضربان حضور هرگز نباید درخواست اصلی را خراب کند */
        }
      })(),
    );
  }
});

// ─────────────────── نگهبان سراسری خطا (Global Error Guard) ───────────────────
// چرا لازم است؟ اگر یک Endpoint به هر دلیلی (مثلاً جدولی که هنوز مهاجرت
// نشده، یا یک استثنای پیش‌بینی‌نشده) استثنا پرتاب کند، بدون این نگهبان
// Cloudflare Workers یک پاسخ ۵۰۰ خامِ غیر-JSON برمی‌گرداند؛ کلاینت (ApiClient)
// نمی‌تواند آن را پارس کند و کاربر فقط «خطای ناشناخته» می‌بیند بدون جزئیات
// قابل پیگیری در لاگ. این نگهبان همیشه یک JSON با قرارداد خطای استاندارد
// برمی‌گرداند و خطای واقعی را در لاگ سرور (wrangler tail) ثبت می‌کند تا
// مشکلات مثل «جدول/ستون مهاجرت‌نشده» سریع قابل تشخیص باشند.
//
// از Migration 0046 به بعد، علاوه بر console.error، همین خطا در جدول
// error_logs هم ذخیره می‌شود (captureError — lib/errorLog.ts) تا از پنل مدیر
// («گزارش خطاهای برنامه») بدون نیاز به `wrangler tail` قابل مرور باشد — دقیقاً
// همان دو مشکل قبلی («ورود ادمین ناموفق» و «تداخل مهاجرت دیتابیس») از این پس
// این‌جا با کد خطا و Stack trace کامل ثبت می‌شوند. با `waitUntil` اجرا می‌شود
// تا پاسخ ۵۰۰ به کاربر معطل درج لاگ نماند.
app.onError((err, c) => {
  console.error(`[unhandled] ${c.req.method} ${c.req.path} →`, err);
  c.executionCtx.waitUntil(
    captureError(c.env.DB, {
      category: 'UNKNOWN',
      severity: 'critical',
      title: `خطای مدیریت‌نشده — ${c.req.method} ${c.req.path}`,
      message: err instanceof Error ? err.message : String(err),
      stackTrace: err instanceof Error ? err.stack ?? null : null,
      source: 'cloudflare_worker',
      screenOrEndpoint: c.req.path,
      httpMethod: c.req.method,
      httpStatus: 500,
    }).catch(() => {}),
  );
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

// ─────────── تولید هوشمند نصاب (Pure AI) + تصویرساز داخلی Gemini ───────────
app.route('/api/v1', aiCurriculumRouter);

// ─────────────────────── امتحانات، نمرات و گواهی‌نامه ───────────────────────
app.route('/api/v1', examsRouter);

// ───────── «آزمون فصل» خودکار با AI (migration 0041، lib/chapterQuiz.ts) ────
app.route('/api/v1', chapterQuizzesRouter);

// ───────── امتحان فاینل چندمضمونهٔ صنف + اعادهٔ ۱۵ روزه (migration 0041) ─────
app.route('/api/v1', finalExamsRouter);

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

// رفع اشکال (پاک‌سازی کد مرده): مسیرهای `/admin/cms/books` و
// `/admin/cms/questions` (routes/cms.ts) هیچ‌گاه از کلاینت واقعی صدا زده
// نمی‌شدند — تب «کتاب‌ها»/«سؤالات» در پنل مدیر از ابتدا به روتر `academy`
// (کتابخانه/بانک سؤال واقعی که شاگردان می‌بینند) وصل بود. `/admin/cms/
// lessons` هم مشابه، به `/admin/curriculum/lessons` منتقل شده بود. پس کل
// `routes/cms.ts` و mountِ آن (به‌همراه جدول‌های `cms_books`/`cms_lessons`/
// `cms_questions` — نگاه کن migrations/0042) حذف شد تا کد بی‌اثر منبع
// سردرگمی/باگ آینده نشود.

// ─────────────────────────── حافظهٔ جمعی (فید اجتماعی) ──────────────────────
app.route('/api/v1', memoryRouter);

// ─────────────────────── آکادمی (کتابخانه/بانک سؤال/پاسخ‌ها) ────────────────
app.route('/api/v1', academyRouter);

// ───────────────────── رقابت مکتب (۵۰ مقام + میشن‌ها + جدول رتبه) ───────────
// migration 0047 + lib/competition.ts. جدول رتبه‌بندی سراسری، مقام شاگرد، و
// میشن‌هایی که تمام بخش‌های برنامه (درس، کارخانگی، امتحان، حافظهٔ جمعی، چت،
// پروفایل، معلم هوشمند، سمینار، کد دعوت، گواهی‌نامه) را به رقابت وصل می‌کنند.
app.route('/api/v1', competitionRouter);
app.route('/api/v1', liveArenaRouter);

// ───────────────────────────── مشاور هوشمند ─────────────────────────────────
app.route('/api/v1', advisorRouter);

// ───────────────── کار خانگی + نمره‌دهی هوشمند (Vision) ─────────────────────
app.route('/api/v1', homeworkRouter);

// ─────────────── ثبت/حذف توکن دستگاه برای Push Notification (FCM) ──────────
app.route('/api/v1', devicesRouter);

// ───────────────────── گزارش خطاهای برنامه (Migration 0046) ─────────────────
// POST /errors (عمومی، از اپ فلاتر) + GET/PATCH/DELETE /admin/error-logs.
app.route('/api/v1', errorLogsRouter);

// ─────────── Cron روزانه: پوش نوتیفیکیشن «فرصت تلاش دوبارهٔ امتحان فاینل» ───
// migration 0043 + lib/finalExamRetakeNotify.ts. تلاش دوم بعد از ۱۵ روز از
// تلاش ناکام به‌طور Lazy (بدون Cron) در routes/finalExams.ts باز می‌شود، اما
// اگر شاگرد خودش سراغ صفحهٔ امتحان نرود کسی به او یادآوری نمی‌کرد؛ این Cron
// هر روز یک‌بار (نگاه کنید به [triggers] در wrangler.toml) چک می‌کند کدام
// تلاش‌های ناکام امروز به ۱۵ روزشان رسیده‌اند و هنوز اطلاع داده نشده‌اند.
async function scheduled(_event: ScheduledEvent, env: Bindings, ctx: ExecutionContext): Promise<void> {
  ctx.waitUntil(
    notifyFinalExamRetakesDue(env).catch((err) => console.error('[scheduled] notifyFinalExamRetakesDue failed —', err)),
  );
  // «آرنای زنده» — هر بار که کرون اجرا می‌شود (طبق [triggers].crons در
  // wrangler.toml)، رویدادهای رسیده به زمان شروع را «زنده» می‌کند و به
  // Durable Object مربوطه سیگنال شروع می‌دهد؛ رویدادهای فراموش‌شده (اگر DO
  // به هر دلیلی پایان نداده) را هم به‌عنوان پشتیبان می‌بندد.
  ctx.waitUntil(
    transitionArenaEvents(env.DB, async (eventId) => {
      const id = env.LIVE_ARENA_ROOM.idFromName(eventId);
      const stub = env.LIVE_ARENA_ROOM.get(id);
      await stub.fetch(`https://live-arena-room/start?eventId=${encodeURIComponent(eventId)}`);
    }).catch((err) => console.error('[scheduled] transitionArenaEvents failed —', err)),
  );
}

export default { fetch: app.fetch, scheduled };
