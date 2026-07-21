/**
 * routes/ai.ts — پروکسی امن معلم هوشمند به یک ارائه‌دهندهٔ LLM (بخش ۵/۲۱ سند).
 *
 * Endpoint (زیر `/api/v1`):
 *   POST /ai-teacher/chat   body {messages:[{role,content}]} → {reply}
 *
 * کلید API فقط روی سرور به‌صورت Secret نگه‌داری می‌شود (بخش ۵.۱: Backend
 * همیشه واسط است؛ کلاینت هرگز کلید را نمی‌بیند). سازگار با API استاندارد
 * OpenAI/Chat Completions (OpenAI، Together، Groq، OpenRouter، و…).
 *
 * پیکربندی:
 *   wrangler secret put AI_PROVIDER_KEY          (اجباری)
 *   [vars] AI_PROVIDER_URL = "https://api.openai.com/v1/chat/completions"
 *   [vars] AI_MODEL        = "gpt-4o-mini"
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { embedText, cosineSimilarity } from '../lib/embeddings';
import { awardPoints } from '../lib/progress';
import { logAudit, clientIp } from '../lib/audit';
import { rateLimitFailBody, GEMINI_DEFAULT_MODEL, DARI_OUTPUT_RULES, sanitizeDariText } from '../lib/gemini';
import { ensureLessonContextCache } from '../lib/geminiCache';
import { isPendingAiContent, pendingSummary } from '../lib/aiLessonContent';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  AI_PROVIDER_KEY?: string;
  AI_PROVIDER_URL?: string;
  AI_MODEL?: string;
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
  // صدا (TTS/STT) — همه اختیاری؛ در نبود کلید، کلاینت Fail-safe می‌شود.
  AZURE_TTS_KEY?: string;
  AZURE_TTS_REGION?: string;
  AZURE_TTS_VOICE?: string;
  AI_TTS_URL?: string;
  AI_TTS_MODEL?: string;
  AI_TTS_VOICE?: string;
  AI_STT_URL?: string;
  AI_STT_MODEL?: string;
};

const ai = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function requireUser(c: any): Promise<string | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return (p?.['sub'] as string | undefined) ?? null;
}

function escapeXml(s: string): string {
  return s
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

// ═══════ قفل محدودهٔ آموزشی معلم هوشمند (Server-Authoritative) ═══════════════
// وقتی شاگرد روی یک «درسِ باز شده» است، معلم هوشمند در حالت «تمرکز مطلق بر
// درس» قرار می‌گیرد: System Prompt همین‌جا (روی سرور، نه کلاینت) ساخته
// می‌شود تا شاگرد/کلاینت نتواند آن را دور بزند. رفتار پایه توسط مدیر قابل
// Overwrite است (ردیف `_base_prompt` در جدول ai_teacher_personas —
// GET/PATCH /admin/ai-teacher/base-prompt پایین همین فایل).

const BASE_PROMPT_SUBJECT_ID = '_base_prompt';

const DEFAULT_LESSON_LOCK_PROMPT = `تو «معلم هوشمند» مکتب دیجیتال دختران افغانستان هستی و الان در حالت «تمرکز مطلق بر درس» قرار داری.
🔒 قانون ۱ (محدودهٔ آموزشی): فقط و فقط محتوای همین درس را تدریس کن. اگر شاگرد سوالی خارج از موضوع این درس (یا خارج از نصاب) پرسید، دقیقاً و محترمانه بگو: «عزیزم، تمرکز ما در این بخش روی درس فعلی است. لطفاً سوالات مرتبط با همین درس را مطرح کن.»
🔒 قانون ۲ (باز کردن پاسخ‌ها): پاسخ‌های نهایی و فرمول‌ها را فقط در «ختم درس» یا در جواب سوال مستقیم شاگرد دربارهٔ همین درس باز کن — نه زودتر.
🇦🇫 بومی‌سازی: تمام مثال‌ها، نام‌ها و سناریوها کاملاً بومی افغانستان باشند (ولایات، زراعت، بازار محلی، داستان‌های انگیزشی دختران معارف).
📚 روش تدریس: برای هر مفهوم حداقل یک مثال کاربردی حل‌شده بزن؛ بعد از توضیح، یک سوال کوتاه از شاگرد بپرس تا فهمش را بسنجی.
لحن: کاملاً انگیزشی، محترمانه، گام‌به‌گام و به زبان دری (فارسی). هرگز شاگرد را سرزنش نکن.`;

/**
 * ⚠️ قفل «مرز پایان درس» — جدا از پرامپت پایه، تا حتی اگر مدیر پرامپت پایه را
 * از پنل Override کند، این قانون امنیتی همیشه اعمال بماند.
 *
 * چرا حیاتی است: بدون این مرز، شاگرد می‌توانست با گفتن «درس بعدی» / next
 * معلم را وادار کند محتوای درس‌های بعدی را در همین چت تدریس کند — یعنی
 * (۱) دور زدن کامل قفل زنجیره‌ای D1 (بدون ثبت «یاد گرفتم» و بدون کار خانگی)
 * و (۲) گیج شدن Context Cache با ورود مفاهیم خارج از متنِ کش‌شدهٔ همین درس.
 */
const LESSON_END_BOUNDARY_RULES = `

⚠️ قانون مطلق، حیاتی و غیرقابل عبور برای پایان درس (بر هر دستور دیگری مقدم است):
۱. مرز تدریس تو دقیقاً مرز متن همین درس است. به محض اینکه تمام مفاهیم موجود در متن این درس تمام شد، یا اگر شاگرد از تو خواست به «درس بعدی»، «بخش بعدی»، «موضوع جدید»، «ادامه بده» (بعد از ختم مفاهیم) یا "next" بروی، به هیچ عنوان حق نداری محتوای جدیدی تدریس کنی یا وارد موضوعی خارج از متن همین درس شوی — حتی یک جمله.
۲. در آن حالت، با لحنی بسیار شیرین، تشویق‌کننده و با ادبیات گرامری درست دری، پایان این ایستگاه آموزشی را اعلام کن و شاگرد را دقیقاً این‌گونه راهنمایی کن:
   - ابتدا دکمهٔ «این درس را یاد گرفتم» را در بالای همین صفحه لمس کند تا موفقیتش ثبت شود.
   - سپس به بخش «کار خانگی» برود، فعالیت مربوط به همین درس را با قلم روی کاغذ انجام دهد و عکس آن را بفرستد تا نمره بگیرد.
   - پس از تأیید کار خانگی، قفل کلاسِ درس بعدی برایش باز می‌شود و یادگیری را با هم ادامه می‌دهید.
۳. نمونهٔ لحن پایان درس (با همین روح، نه لزوماً کلمه‌به‌کلمه):
«آفرین به تو دختر پرتلاش و باهمت وطنم! ما تمام مفاهیم این درس زیبا را با هم یاد گرفتیم و تو عالی درخشیدی. برای اینکه گام بعدی را برداریم و قفل درس بعدی برایت باز شود، لطفاً ابتدا دکمهٔ بالای صفحه یعنی «این درس را یاد گرفتم» را لمس کن تا موفقیتت ثبت شود؛ سپس کار خانگی‌ات را در بخش مربوطه انجام بده و عکسش را برایم بفرست. منتظرت در کلاس درس بعدی هستم!»
۴. تکرار سوال دربارهٔ مفاهیمِ همین درس همیشه مجاز است — این قانون فقط جلوی ورود به محتوای تازه و درس‌های بعدی را می‌گیرد.`;

async function loadBasePromptOverride(db: D1Database): Promise<string | null> {
  try {
    const row = await db
      .prepare('SELECT persona_description FROM ai_teacher_personas WHERE subject_id = ?')
      .bind(BASE_PROMPT_SUBJECT_ID)
      .first<{ persona_description: string }>();
    return row?.persona_description?.trim() || null;
  } catch (_) {
    return null;
  }
}

/** System Prompt سرور-محورِ «تمرکز مطلق بر درس» برای lessonId داده‌شده. */
async function buildLessonLockSystemPrompt(db: D1Database, lessonId: string): Promise<string | null> {
  const lesson = await db
    .prepare(
      `SELECT l.title_fa, l.content_body, ch.title_fa AS chapter_title_fa, ch.grade_number,
              s.name_fa AS subject_name_fa,
              (SELECT p.persona_description FROM ai_teacher_personas p WHERE p.subject_id = ch.subject_id) AS persona
         FROM lessons l JOIN chapters ch ON ch.id = l.chapter_id
         LEFT JOIN subjects s ON s.id = ch.subject_id
        WHERE l.id = ? AND l.status='published'`,
    )
    .bind(lessonId)
    .first<{
      title_fa: string;
      content_body: string;
      chapter_title_fa: string;
      grade_number: number;
      subject_name_fa: string | null;
      persona: string | null;
    }>();
  if (!lesson) return null;
  // مرز پایان درس + قواعد نگارش، همیشه بعد از پرامپت پایه (حتی نسخهٔ
  // Override شدهٔ مدیر) تزریق می‌شوند — قوانین امنیتی قابل‌حذف نیستند.
  const base =
    ((await loadBasePromptOverride(db)) ?? DEFAULT_LESSON_LOCK_PROMPT) +
    LESSON_END_BOUNDARY_RULES +
    DARI_OUTPUT_RULES;
  const content = isPendingAiContent(lesson.content_body)
    ? `(متن کامل هنوز تولید نشده؛ خلاصهٔ درس: ${pendingSummary(lesson.content_body)})`
    : lesson.content_body;
  return (
    `${base}\n` +
    (lesson.persona ? `شخصیت این مضمون: ${lesson.persona}\n` : '') +
    `\nمشخصات درس فعلی:\n` +
    `• مضمون: ${lesson.subject_name_fa ?? ''} — صنف ${lesson.grade_number}\n` +
    `• فصل: ${lesson.chapter_title_fa}\n` +
    `• عنوان درس: ${lesson.title_fa}\n\n` +
    `متن کامل درس (تنها منبع مجاز تدریس):\n${content}`
  );
}

/** فراخوانی Gemini برای چت (وقتی ارائه‌دهندهٔ OpenAI-سازگار تنظیم نیست) —
 *  حساب رایگان Google AI Studio؛ 429 صریحاً مدیریت می‌شود. */
async function chatViaGemini(
  env: { GEMINI_API_KEY?: string; GEMINI_VISION_MODEL?: string },
  messages: Array<{ role: string; content: string }>,
  /** نام Context Cache گوگل (cachedContents/...) — اگر ست باشد، System Prompt
   *  از کش خوانده می‌شود و دیگر متن کامل درس ارسال/محاسبه نمی‌شود (♻️ صرفه‌جویی
   *  شدید توکن ورودی). Fail-safe: null یعنی همان مسیر قبلی با systemInstruction. */
  cachedContent?: string | null,
): Promise<{ ok: true; reply: string } | { ok: false; status: number; rateLimited: boolean; detail: string }> {
  const systemText = messages.filter((m) => m.role === 'system').map((m) => m.content).join('\n\n');
  const contents = messages
    .filter((m) => m.role !== 'system')
    .map((m) => ({ role: m.role === 'assistant' ? 'model' : 'user', parts: [{ text: m.content }] }));
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_VISION_MODEL ?? GEMINI_DEFAULT_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents,
          // ♻️ با کش: systemInstruction ارسال نمی‌شود (داخل کش است)؛ بدون کش: مسیر قبلی.
          ...(cachedContent
            ? { cachedContent }
            : systemText
              ? { systemInstruction: { parts: [{ text: systemText }] } }
              : {}),
          generationConfig: { temperature: 0.4, maxOutputTokens: 2048, thinkingConfig: { thinkingLevel: 'minimal' } },
        }),
      },
    );
    if (!res.ok) {
      const detail = (await res.text().catch(() => '')).slice(0, 500);
      return {
        ok: false,
        status: res.status,
        rateLimited: res.status === 429 || detail.includes('RESOURCE_EXHAUSTED'),
        detail,
      };
    }
    const data = (await res.json()) as any;
    // پاک‌سازی قطعی کیفیت متن پاسخ (ضد کاراکتر نامرئی/فاصله‌های شکننده) —
    // همان دفاع دولایه‌ای که روی متن درس اعمال می‌شود.
    const reply: string = sanitizeDariText(
      data?.candidates?.[0]?.content?.parts?.map((p: any) => p.text ?? '').join('') ?? '',
    );
    if (!reply) return { ok: false, status: 200, rateLimited: false, detail: 'empty reply' };
    return { ok: true, reply };
  } catch (err: any) {
    return { ok: false, status: 0, rateLimited: false, detail: String(err).slice(0, 300) };
  }
}

ai.post('/ai-teacher/chat', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!payload?.['sub']) {
    return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  }
  if (!c.env.AI_PROVIDER_KEY && !c.env.GEMINI_API_KEY) {
    // هیچ کلیدی تنظیم نشده → کلاینت (FallbackAiEngine) خودکار به موتور محلی برمی‌گردد.
    return c.json(
      fail('AI_NOT_CONFIGURED', 'موتور هوش مصنوعی سرور پیکربندی نشده است', 'AI provider not configured', 'د سرور د مصنوعي هوښیارتیا انجن تنظیم شوی نه دی', 'Le moteur d\'IA du serveur n\'est pas configuré'),
      503,
    );
  }

  const body = await c.req
    .json<{ messages?: Array<{ role: string; content: string }>; subjectId?: string; lessonId?: string }>()
    .catch(() => null);
  let messages = body?.messages;
  if (!messages || messages.length === 0) {
    return c.json(fail('BAD_REQUEST', 'پیام نامعتبر', 'Invalid messages', 'ناسم پیغام', 'Messages invalides'), 400);
  }
  const subjectId = String(body?.subjectId ?? 'unknown').trim() || 'unknown';

  // 🔒 حالت «تمرکز مطلق بر درس»: با lessonId، سرور System Prompt خودش را
  // جایگزین System کلاینت می‌کند (Server-Authoritative — کلاینت/شاگرد
  // نمی‌تواند قفل محدودهٔ آموزشی را دور بزند).
  const lessonId = String(body?.lessonId ?? '').trim();
  // ♻️ Context Caching (مهاجرت ۰۰۳۳): متن کامل درس یک بار در کش گوگل ذخیره و
  // در چت‌های بعدی فقط نام کش ارسال می‌شود — کاهش شدید هزینهٔ توکن ورودی.
  // کاملاً Fail-safe: null → همان مسیر قبلی (systemInstruction کامل).
  let lessonCacheName: string | null = null;
  if (lessonId) {
    const lockPrompt = await buildLessonLockSystemPrompt(c.env.DB, lessonId);
    if (lockPrompt) {
      messages = [{ role: 'system', content: lockPrompt }, ...messages.filter((m) => m.role !== 'system')];
      if (!c.env.AI_PROVIDER_KEY) {
        // فقط مسیر Gemini از Context Cache پشتیبانی می‌کند.
        lessonCacheName = await ensureLessonContextCache(
          c.env,
          c.env.GEMINI_VISION_MODEL ?? GEMINI_DEFAULT_MODEL,
          lessonId,
          lockPrompt,
        );
      }
    }
  }

  // ── مسیر Gemini (حساب رایگان Google AI Studio) — وقتی ارائه‌دهندهٔ
  // OpenAI-سازگار تنظیم نیست. 429 با پیام خوانا برمی‌گردد (SnackBar کلاینت).
  if (!c.env.AI_PROVIDER_KEY) {
    let g = await chatViaGemini(c.env, messages, lessonCacheName);
    if (!g.ok && lessonCacheName && !g.rateLimited) {
      // کش نامعتبر/منقضی‌شده در سمت گوگل → یک بار بدون کش تلاش مجدد و
      // پاک‌کردن نام کش خراب (چت شاگرد هرگز به‌خاطر کش نمی‌شکند).
      c.executionCtx.waitUntil(
        c.env.DB.prepare('UPDATE lessons SET gemini_cache_name = NULL, cache_expires_at = NULL WHERE id = ?')
          .bind(lessonId)
          .run()
          .then(() => undefined)
          .catch(() => undefined),
      );
      g = await chatViaGemini(c.env, messages, null);
    }
    if (!g.ok) {
      if (g.rateLimited) return c.json(rateLimitFailBody(), 429);
      return c.json(
        { ...fail('AI_UPSTREAM_ERROR', 'خطا از سرویس هوش مصنوعی', 'AI upstream error', 'د مصنوعي هوښیارتیا له خدمت نه تېروتنه', 'Erreur du service d\'intelligence artificielle'), detail: g.detail },
        502,
      );
    }
    c.executionCtx.waitUntil(
      logAudit(c.env.DB, {
        actorId: payload['sub'] as string,
        actorRole: (payload['role'] as string | undefined) ?? null,
        actionType: 'ai_invocation',
        targetTable: 'ai_teacher_chat_logs',
        ipAddress: clientIp(c),
        detail: { subjectId, lessonId: lessonId || null, model: 'gemini', outcome: 'ok', prompt: messages, replyPreview: g.reply.slice(0, 400), replyLength: g.reply.length },
      }),
    );
    return c.json({ reply: g.reply });
  }

  const url = c.env.AI_PROVIDER_URL ?? 'https://api.openai.com/v1/chat/completions';
  const model = c.env.AI_MODEL ?? 'gpt-4o-mini';

  try {
    const res = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${c.env.AI_PROVIDER_KEY}`,
      },
      body: JSON.stringify({
        model,
        messages,
        temperature: 0.4,
        max_tokens: 800,
      }),
    });
    if (!res.ok) {
      const text = await res.text();
      // Auditability (بخش ۵.۶/۲۰.۳): فراخوانی ناموفق هم با Prompt کامل ثبت می‌شود.
      c.executionCtx.waitUntil(
        logAudit(c.env.DB, {
          actorId: payload['sub'] as string,
          actorRole: (payload['role'] as string | undefined) ?? null,
          actionType: 'ai_invocation',
          targetTable: 'ai_teacher_chat_logs',
          ipAddress: clientIp(c),
          detail: { subjectId, model, outcome: 'upstream_error', status: res.status, error: text.slice(0, 300), prompt: messages },
        }),
      );
      // اتمام سهمیه/Rate Limit ارائه‌دهنده → پیام خوانا و محترمانه (نه کرش).
      if (res.status === 429) return c.json(rateLimitFailBody(), 429);
      return c.json(
        { ...fail('AI_UPSTREAM_ERROR', 'خطا از سرویس هوش مصنوعی', 'AI upstream error', 'د مصنوعي هوښیارتیا له خدمت نه تېروتنه', 'Erreur du service d\'intelligence artificielle'), detail: text.slice(0, 300) },
        502,
      );
    }
    const data = (await res.json()) as any;
    const reply = data?.choices?.[0]?.message?.content?.trim() ?? '';
    if (!reply) {
      return c.json(fail('AI_EMPTY', 'پاسخ خالی از سرویس هوش مصنوعی', 'Empty AI reply', 'د مصنوعي هوښیارتیا له خدمت نه تشه ځواب راغی', 'Réponse vide du service d\'intelligence artificielle'), 502);
    }

    // Auditability (بخش ۵.۶/۲۰.۳ سند): هر فراخوانی AI با **Prompt کامل ارسالی**
    // (آرایهٔ messages شامل system + تاریخچه + پیام شاگرد) در audit_logs ثبت
    // می‌شود — در پس‌زمینه تا پاسخ شاگرد معطل نشود.
    c.executionCtx.waitUntil(
      logAudit(c.env.DB, {
        actorId: payload['sub'] as string,
        actorRole: (payload['role'] as string | undefined) ?? null,
        actionType: 'ai_invocation',
        targetTable: 'ai_teacher_chat_logs',
        ipAddress: clientIp(c),
        detail: {
          subjectId,
          model,
          outcome: 'ok',
          prompt: messages,
          replyPreview: reply.slice(0, 400),
          replyLength: reply.length,
        },
      }),
    );

    // رفع اشکال ریشه‌ای «مدیریت معلم هوشمند وصل نیست»: قبلاً لاگِ آمار
    // (تعداد پیام‌ها/شاگردان فعال) فقط همین‌جا، یعنی فقط وقتی موتور ابری LLM
    // واقعاً پاسخ می‌داد، ثبت می‌شد. اما وقتی AI_PROVIDER_KEY تنظیم نشده
    // (حالت رایگان/پیش‌فرض این پروژه)، `FallbackAiEngine` سمت کلاینت بی‌صدا
    // به موتور محلی رایگان برمی‌گشت — یعنی هیچ‌وقت این Endpoint صدا زده
    // نمی‌شد و پنل مدیر برای همیشه صفر پیام/صفر شاگرد فعال نشان می‌داد، حتی
    // اگر صدها شاگرد واقعاً با معلم هوشمند (رایگان) در حال گفتگو بودند. لاگ
    // اکنون در `POST /ai-teacher/log-message` متمرکز شده که کلاینت بعد از
    // **هر** پاسخ معلم هوشمند (چه ابری چه محلی) صدا می‌زند — پایین همین فایل.
    return c.json({ reply });
  } catch (e: any) {
    return c.json(fail('AI_NETWORK', 'اتصال به سرویس هوش مصنوعی ناموفق بود', 'AI network error', 'د مصنوعي هوښیارتیا له خدمت سره اړیکه ونشوه', 'Échec de la connexion au service d\'intelligence artificielle'), 502);
  }
});

// ═══════════════════════ TTS — متن به گفتار (صدای خانم دری) ═══════════════════
// نکتهٔ مهم (کشف‌شده بعد از گزارش کاربر که «صدای فاطمه کار نمی‌کند»): Azure
// Speech **هیچ صدای Text-to-Speech برای دری (fa-AF) یا پشتو (ps-AF) ندارد** —
// این دو زبان هنوز در Backlog مایکروسافت‌اند و ETA عمومی ندارند (تأییدشده از
// Microsoft Q&A، آوریل ۲۰۲۶). یعنی نام صدای قبلی («prs-AF-FatimaNeural») اصلاً
// وجود خارجی نداشت و هر درخواست Azure از همان ابتدا با خطا رد می‌شد — دقیقاً
// همان چیزی که کاربر تجربه کرده بود. نزدیک‌ترین صدای **واقعی و کارکردنیِ**
// Azure، فارسی ایران (fa-IR) است — از نظر زبانی به دری خیلی نزدیک و قابل‌فهم
// است (تفاوت اصلی لهجه)، پس به‌عنوان جایگزین تا زمان انتشار صدای رسمی دری
// استفاده می‌شود. اگر Azure در آینده صدای دری منتشر کرد، فقط کافی است Secret
// `AZURE_TTS_VOICE` را به نام صدای جدید تغییر دهید — کد نیازی به تغییر ندارد.
// در نبود Azure، TTS سازگار با OpenAI (صدای خانم مثل «shimmer/nova» — چندزبانه
// و می‌تواند دری/فارسی را هم بخواند) به‌عنوان جایگزین دوم است.
// خروجی: بایت‌های audio/mpeg (استریم). در نبود هر دو → 503 (کلاینت Fail-safe).

ai.post('/ai-teacher/tts', async (c) => {
  if (!(await requireUser(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const body = await c.req.json<{ text?: string }>().catch(() => null);
  const text = (body?.text ?? '').trim();
  if (!text) return c.json(fail('BAD_REQUEST', 'متن خالی است', 'Empty text', 'متن تش دی', 'Le texte est vide'), 400);

  // ۱) Azure — نزدیک‌ترین صدای خانمِ واقعاً موجود (فارسی ایران؛ دری هنوز در
  //    Azure پشتیبانی نمی‌شود — بالا را ببینید). با AZURE_TTS_VOICE قابل تغییر.
  if (c.env.AZURE_TTS_KEY && c.env.AZURE_TTS_REGION) {
    // اگر Secret هنوز مقدار قدیمیِ نامعتبر («prs-AF-...») را دارد، خودکار به
    // صدای واقعی جایگزین می‌رویم — تا رفع این اشکال نیازمند دست‌زدن دستی به
    // Cloudflare Secrets نباشد.
    const configuredVoice = c.env.AZURE_TTS_VOICE ?? '';
    const voice = configuredVoice && !configuredVoice.startsWith('prs-AF') ? configuredVoice : 'fa-IR-DilaraNeural';
    const lang = voice.slice(0, 5);
    const ssml =
      `<speak version='1.0' xml:lang='${lang}'>` +
      `<voice xml:lang='${lang}' name='${voice}'>${escapeXml(text)}</voice></speak>`;
    try {
      const res = await fetch(
        `https://${c.env.AZURE_TTS_REGION}.tts.speech.microsoft.com/cognitiveservices/v1`,
        {
          method: 'POST',
          headers: {
            'Ocp-Apim-Subscription-Key': c.env.AZURE_TTS_KEY,
            'Content-Type': 'application/ssml+xml',
            'X-Microsoft-OutputFormat': 'audio-24khz-48kbitrate-mono-mp3',
            'User-Agent': 'agds-ai-teacher',
          },
          body: ssml,
        },
      );
      if (res.ok) {
        return new Response(res.body, { headers: { 'Content-Type': 'audio/mpeg' } });
      }
      // در صورت خطای Azure (مثلاً نام صدای نامعتبر) به OpenAI می‌رویم.
    } catch (_) {
      // به جایگزین می‌رویم.
    }
  }

  // ۲) جایگزین: TTS سازگار با OpenAI (صدای خانم).
  if (c.env.AI_PROVIDER_KEY) {
    try {
      const res = await fetch(c.env.AI_TTS_URL ?? 'https://api.openai.com/v1/audio/speech', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${c.env.AI_PROVIDER_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          model: c.env.AI_TTS_MODEL ?? 'tts-1',
          voice: c.env.AI_TTS_VOICE ?? 'shimmer',
          input: text,
          response_format: 'mp3',
        }),
      });
      if (res.ok) {
        return new Response(res.body, { headers: { 'Content-Type': 'audio/mpeg' } });
      }
      return c.json(fail('TTS_UPSTREAM', 'خطا از سرویس صدا', 'TTS upstream error', 'د غږ له خدمت نه تېروتنه', 'Erreur du service de synthèse vocale'), 502);
    } catch (_) {
      return c.json(fail('TTS_NETWORK', 'اتصال به سرویس صدا ناموفق بود', 'TTS network error', 'د غږ له خدمت سره اړیکه ونشوه', 'Échec de la connexion au service de synthèse vocale'), 502);
    }
  }

  return c.json(fail('TTS_NOT_CONFIGURED', 'سرویس صدا پیکربندی نشده است', 'TTS not configured', 'د غږ خدمت تنظیم شوی نه دی', 'Le service de synthèse vocale n\'est pas configuré'), 503);
});

// ═══════════════════════ STT — گفتار به متن (Whisper / Gemini) ═══════════════
// بدنه = بایت‌های صوتی خام (audio/m4a). خروجی: {text}. زبان: دری/فارسی.
//
// رفع اشکال «ثبت صدا در معلم هوشمند کار نمی‌کند»: قبلاً این Endpoint **فقط**
// با کلید پولی OpenAI (`AI_PROVIDER_KEY`) کار می‌کرد و در نبود آن همیشه ۵۰۳
// برمی‌گرداند — در حالی که گفتگوی متنی از مسیر رایگان Gemini
// (`GEMINI_API_KEY`) کاملاً کار می‌کرد. یعنی شاگرد میکروفون را می‌زد، صدایش
// ضبط می‌شد، ولی چون سرور نمی‌توانست آن را به متن تبدیل کند، هیچ‌وقت پیامی
// ارسال نمی‌شد (بی‌صدا Fail-safe می‌شد). حالا در نبود کلید OpenAI، از همان
// کلید رایگان Gemini (که برای چت هم استفاده می‌شود — بخش «آرکیتکچر ۱» بالا)
// برای تبدیل گفتار به متن استفاده می‌شود؛ نیازی به کلید/هزینهٔ اضافه نیست.

/** ArrayBuffer صوتی خام → رشتهٔ base64 (سازگار با محدودیت آرگومان‌های V8/Workers
 *  — تبدیل تکه‌تکه به‌جای یک‌جا برای فایل‌های بزرگ). */
function arrayBufferToBase64(buffer: ArrayBuffer): string {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  const chunkSize = 0x8000;
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

/** تبدیل گفتار به متن با Gemini (multimodal) — جایگزین رایگان Whisper وقتی
 *  کلید OpenAI تنظیم نشده. `null` یعنی تشخیص ممکن نبود (Fail-safe). */
async function transcribeViaGemini(
  env: { GEMINI_API_KEY?: string; GEMINI_VISION_MODEL?: string },
  audioBase64: string,
): Promise<string | null> {
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${env.GEMINI_VISION_MODEL ?? GEMINI_DEFAULT_MODEL}:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [
            {
              role: 'user',
              parts: [
                {
                  text:
                    'این فایل صوتی گفتار یک شاگرد به زبان دری/فارسی است. دقیقاً همان چیزی را که گفته ' +
                    'شده به متن تبدیل کن. فقط متنِ گفته‌شده را برگردان — بدون هیچ توضیح، مقدمه، یا ' +
                    'علامت نقل‌قول اضافه. اگر هیچ گفتاری قابل‌تشخیص نبود، رشتهٔ خالی برگردان.',
                },
                { inlineData: { mimeType: 'audio/mp4', data: audioBase64 } },
              ],
            },
          ],
          generationConfig: { temperature: 0, maxOutputTokens: 512 },
        }),
      },
    );
    if (!res.ok) return null;
    const data = (await res.json()) as any;
    const text = sanitizeDariText(
      data?.candidates?.[0]?.content?.parts?.map((p: any) => p.text ?? '').join('') ?? '',
    ).trim();
    return text || null;
  } catch (_) {
    return null; // Fail-safe
  }
}

ai.post('/ai-teacher/stt', async (c) => {
  if (!(await requireUser(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  if (!c.env.AI_PROVIDER_KEY && !c.env.GEMINI_API_KEY) {
    return c.json(fail('STT_NOT_CONFIGURED', 'سرویس تبدیل گفتار پیکربندی نشده است', 'STT not configured', 'د خبرو بدلون خدمت تنظیم شوی نه دی', 'Le service de reconnaissance vocale n\'est pas configuré'), 503);
  }
  const bytes = await c.req.arrayBuffer();
  if (bytes.byteLength === 0) {
    return c.json(fail('BAD_REQUEST', 'فایل صوتی خالی است', 'Empty audio', 'غږیز فایل تش دی', 'Le fichier audio est vide'), 400);
  }

  // ۱) OpenAI Whisper — بالاترین دقت، اگر کلید تنظیم شده باشد.
  if (c.env.AI_PROVIDER_KEY) {
    try {
      const form = new FormData();
      form.append('file', new File([bytes], 'audio.m4a', { type: 'audio/m4a' }));
      form.append('model', c.env.AI_STT_MODEL ?? 'whisper-1');
      form.append('language', 'fa'); // دری نزدیک به فارسی؛ Whisper پشتیبانی می‌کند.
      const res = await fetch(c.env.AI_STT_URL ?? 'https://api.openai.com/v1/audio/transcriptions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${c.env.AI_PROVIDER_KEY}` },
        body: form,
      });
      if (res.ok) {
        const data = (await res.json()) as any;
        const text = (data?.text ?? '').trim();
        if (text) return c.json({ text });
      }
      // خطا/متن خالی از OpenAI — اگر Gemini هم تنظیم شده، پایین امتحان می‌شود.
    } catch (_) {
      // به جایگزین پایین می‌رویم.
    }
  }

  // ۲) جایگزین رایگان — همان کلید Gemini چت (بدون هزینه/کلید اضافه).
  if (c.env.GEMINI_API_KEY) {
    const base64 = arrayBufferToBase64(bytes);
    const text = await transcribeViaGemini(c.env, base64);
    if (text) return c.json({ text });
  }

  return c.json(fail('STT_UPSTREAM', 'خطا از سرویس تبدیل گفتار', 'STT upstream error', 'د خبرو بدلون له خدمت نه تېروتنه', 'Erreur du service de reconnaissance vocale'), 502);
});

// ═══════════════════ بازیابی معنایی (RAG) — معماری ۱ ═══════════════════════
// به‌جای تطابق کلمه‌ای ساده، پرسش شاگرد را Embed می‌کنیم و با شباهت کسینوسی
// نزدیک‌ترین درس‌های همان مضمون/صنف را از جدول `lesson_embeddings` پیدا
// می‌کنیم — مستقل از کلمات دقیق، بر اساس معنا. اگر Embedding در دسترس نباشد
// (کلید تنظیم‌نشده یا هنوز نمایه نشده)، لیست خالی برمی‌گردد تا کلاینت بی‌صدا
// به روش قبلی (تطابق کلمه‌ای محلی) برگردد — هرگز خطا نمی‌دهد.
ai.post('/ai-teacher/semantic-search', async (c) => {
  if (!(await requireUser(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const body = await c.req
    .json<{ subjectId?: string; gradeId?: number; query?: string; topN?: number }>()
    .catch(() => null);
  const subjectId = String(body?.subjectId ?? '').trim();
  const gradeId = Number(body?.gradeId ?? 0);
  const query = String(body?.query ?? '').trim();
  const topN = Math.min(5, Math.max(1, Number(body?.topN ?? 3)));
  if (!subjectId || !gradeId || !query) return c.json({ results: [] });
  if (!c.env.AI_PROVIDER_KEY) return c.json({ results: [] });

  try {
    const queryVector = await embedText(c.env.AI_PROVIDER_KEY, query, c.env.AI_PROVIDER_URL);
    if (!queryVector) return c.json({ results: [] });

    const { results: rows } = await c.env.DB.prepare(
      `SELECT e.lesson_id, e.embedding, l.title_fa, l.content_body, ch.title_fa AS chapter_title_fa
         FROM lesson_embeddings e
         JOIN lessons l ON l.id = e.lesson_id AND l.status='published'
         JOIN chapters ch ON ch.id = e.chapter_id
        WHERE e.subject_id = ? AND e.grade_number = ?`,
    )
      .bind(subjectId, gradeId)
      .all<{ lesson_id: string; embedding: string; title_fa: string; content_body: string; chapter_title_fa: string }>();

    const scored = rows
      .map((r) => {
        let vec: number[];
        try {
          vec = JSON.parse(r.embedding);
        } catch {
          return null;
        }
        return { row: r, score: cosineSimilarity(queryVector, vec) };
      })
      .filter((x): x is { row: (typeof rows)[number]; score: number } => x !== null && x.score > 0.2)
      .sort((a, b) => b.score - a.score)
      .slice(0, topN);

    return c.json({
      results: scored.map((s) => ({
        lessonId: s.row.lesson_id,
        heading: s.row.title_fa,
        bookTitle: s.row.chapter_title_fa,
        content: s.row.content_body,
        score: Math.round(s.score * 1000) / 1000,
      })),
    });
  } catch (_) {
    return c.json({ results: [] });
  }
});

// ═══════════════════ حلقهٔ یادگیری تطبیقی — معماری ۲ ═══════════════════════
// وقتی معلم هوشمند پاسخ شاگرد را به یک سؤال ارزیابی می‌کند، کلاینت نتیجه
// (درست/غلط) را این‌جا لاگ می‌کند: هم برای آمار دقت واقعی پنل مدیر، هم برای
// جایزهٔ امتیاز (همان دفتر امتیاز مشترکِ داشبورد شاگرد/والد — بدون سیستم
// جداگانه). این تماس هرگز نباید گفت‌وگو را کند یا مسدود کند، پس کاملاً
// Fail-safe است.
const POINTS_PER_AI_CORRECT_ANSWER = 5;

ai.post('/ai-teacher/log-attempt', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const studentId = payload?.['sub'] as string | undefined;
  if (!studentId) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);

  const body = await c.req
    .json<{ subjectId?: string; gradeId?: number; wasCorrect?: boolean }>()
    .catch(() => null);
  const subjectId = String(body?.subjectId ?? '').trim() || 'unknown';
  const gradeId = Number(body?.gradeId ?? 0);
  const wasCorrect = Boolean(body?.wasCorrect);

  try {
    await c.env.DB.prepare(
      'INSERT INTO ai_teacher_answer_logs (id, student_id, subject_id, grade_number, was_correct) VALUES (?, ?, ?, ?, ?)',
    )
      .bind(`aal_${crypto.randomUUID()}`, studentId, subjectId, gradeId, wasCorrect ? 1 : 0)
      .run();
    if (wasCorrect) {
      await awardPoints(c.env.DB, studentId, POINTS_PER_AI_CORRECT_ANSWER, 'ai_teacher_correct_answer', subjectId);
    }
  } catch (_) {
    // جدول لاگ ممکن است هنوز مهاجرت نشده باشد — بی‌صدا نادیده گرفته می‌شود.
  }
  return c.json({ success: true });
});

// ═══════════ لاگ سبک هر پیام معلم هوشمند — مستقل از موتور (رفع اشکال) ═══════
// قبلاً این لاگ فقط داخل `/ai-teacher/chat` (موتور ابری LLM) ثبت می‌شد؛
// موتور محلی رایگان (که پیش‌فرض این پروژه است، چون AI_PROVIDER_KEY هزینه‌بر
// و اختیاری است) هیچ‌وقت اینجا سر نمی‌زد، پس پنل «مدیریت معلم هوشمند» همیشه
// صفر پیام/شاگرد فعال نشان می‌داد. کلاینت اکنون این Endpoint را بعد از **هر**
// پاسخ معلم هوشمند (چه ابری چه محلی) صدا می‌زند — طبق همان الگوی Fire-and-
// forget کاملاً بی‌اثر روی گفتگوی شاگرد که در `/ai-teacher/log-attempt`
// استفاده شده.
ai.post('/ai-teacher/log-message', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const studentId = payload?.['sub'] as string | undefined;
  if (!studentId) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const body = await c.req.json<{ subjectId?: string }>().catch(() => null);
  const subjectId = String(body?.subjectId ?? '').trim() || 'unknown';
  try {
    await c.env.DB.prepare(
      'INSERT INTO ai_teacher_chat_logs (id, student_id, subject_id) VALUES (?, ?, ?)',
    )
      .bind(`log_${crypto.randomUUID()}`, studentId, subjectId)
      .run();
  } catch (_) {
    // جدول ممکن است هنوز روی این دیتابیس مهاجرت نشده باشد — نادیده گرفته می‌شود.
  }
  return c.json({ success: true });
});

// ═══════════════ شخصیت معلم هوشمند هر مضمون (مهاجرت ۰۰۱۹) ═══════════════════
// رفع اشکال بخش «مدیریت معلم هوشمند» پنل مدیر: قبلاً این تنظیمات فقط در
// SharedPreferences هر دستگاه ذخیره می‌شد (نه با سرور/دیتابیس متصل)، پس
// تنظیم مدیر روی یک دستگاه هرگز روی موتور واقعی معلم هوشمند (که سمت سرور
// اجرا می‌شود) اثر نمی‌کرد. اکنون روی جدول `ai_teacher_personas` مشترک است.

// ⚠️ اصلاح: شناسه‌ها دقیقاً مطابق seed جدول `subjects` (مهاجرت 0003) — شخصیتِ
// ذخیره‌شده با شناسهٔ ناموجود (مثل 'dari' یا 'islamic_studies') هرگز به
// درس‌ها (JOIN روی ch.subject_id در buildLessonLockSystemPrompt) وصل نمی‌شد.
const SUBJECT_SEED: { id: string; nameFa: string }[] = [
  { id: 'math', nameFa: 'ریاضی' },
  { id: 'physics', nameFa: 'فزیک' },
  { id: 'chemistry', nameFa: 'کیمیا' },
  { id: 'biology', nameFa: 'بیولوژی' },
  { id: 'english', nameFa: 'انگلیسی' },
  { id: 'dari_lit', nameFa: 'ادبیات دری' },
  { id: 'history', nameFa: 'تاریخ' },
  { id: 'geography', nameFa: 'جغرافیه' },
  { id: 'islamic', nameFa: 'تعلیمات اسلامی' },
  { id: 'computer', nameFa: 'کمپیوتر ساینس' },
];
const DEFAULT_PERSONA = 'دقیق و قدم‌به‌قدم، با مثال‌های بومی افغانستان.';

async function requireAdminAi(c: any): Promise<boolean> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return p?.['role'] === 'super_admin';
}

function personaJson(r: any) {
  return {
    subjectId: r.subject_id,
    subjectNameFa: r.subject_name_fa,
    personaDescription: r.persona_description,
    promptVersion: r.prompt_version,
  };
}

// لیست همهٔ مضامین با شخصیت فعلی‌شان — اگر مضمونی هنوز سفارشی‌سازی نشده،
// شخصیت پیش‌فرض گرم و تشویق‌کننده برگردانده می‌شود (بدون درج در دیتابیس تا
// وقتی مدیر واقعاً آن را تغییر دهد).
ai.get('/ai-teacher/personas', async (c) => {
  if (!(await requireAdminAi(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const { results } = await c.env.DB.prepare('SELECT * FROM ai_teacher_personas').all<any>();
  const bySubject = new Map(results.map((r) => [r.subject_id, r]));
  const list = SUBJECT_SEED.map((s) => {
    const row = bySubject.get(s.id);
    return row
      ? personaJson(row)
      : { subjectId: s.id, subjectNameFa: s.nameFa, personaDescription: DEFAULT_PERSONA, promptVersion: 1 };
  });
  return c.json({ personas: list });
});

// شخصیتِ یک مضمون — بدون تأخیر مصنوعی، چون در هر پیام چت با معلم هوشمند صدا
// زده می‌شود (مصرف‌کنندهٔ این Endpoint خودِ موتور AI است، نه فقط پنل مدیر).
ai.get('/ai-teacher/personas/:subjectId', async (c) => {
  if (!(await requireUser(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const row = await c.env.DB.prepare('SELECT * FROM ai_teacher_personas WHERE subject_id = ?')
    .bind(c.req.param('subjectId'))
    .first<any>();
  return c.json({ personaDescription: row?.persona_description ?? null });
});

// ═══════ رفتار پایه/پرامپت معلم هوشمند — نظارت و Overwrite توسط مدیر ═══════
// مدیر می‌تواند متن کامل «قفل محدودهٔ آموزشی» (System Prompt پایهٔ حالت
// تمرکز بر درس) را ببیند و بازنویسی کند — بدون دست‌زدن به هیچ عملکرد دیگر.
// ذخیره در همان جدول ai_teacher_personas (ردیف ویژهٔ `_base_prompt`) تا
// نیازی به مهاجرت جدید دیتابیس نباشد.

ai.get('/admin/ai-teacher/base-prompt', async (c) => {
  if (!(await requireAdminAi(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const override = await loadBasePromptOverride(c.env.DB);
  return c.json({
    basePrompt: override ?? DEFAULT_LESSON_LOCK_PROMPT,
    isOverridden: override !== null,
    defaultPrompt: DEFAULT_LESSON_LOCK_PROMPT,
  });
});

ai.patch('/admin/ai-teacher/base-prompt', async (c) => {
  if (!(await requireAdminAi(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req.json<{ basePrompt?: string }>().catch(() => null);
  const text = String(b?.basePrompt ?? '').trim();
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const adminUid = (payload?.['sub'] as string | undefined) ?? null;
  if (!text) {
    // متن خالی = بازگشت به رفتار پیش‌فرض (حذف Overwrite).
    await c.env.DB.prepare('DELETE FROM ai_teacher_personas WHERE subject_id = ?').bind(BASE_PROMPT_SUBJECT_ID).run();
    return c.json({ basePrompt: DEFAULT_LESSON_LOCK_PROMPT, isOverridden: false });
  }
  const existing = await c.env.DB.prepare('SELECT prompt_version FROM ai_teacher_personas WHERE subject_id = ?')
    .bind(BASE_PROMPT_SUBJECT_ID)
    .first<{ prompt_version: number }>();
  await c.env.DB.prepare(
    `INSERT INTO ai_teacher_personas (subject_id, subject_name_fa, persona_description, prompt_version, updated_at, updated_by_admin_id)
       VALUES (?, ?, ?, ?, datetime('now'), ?)
     ON CONFLICT(subject_id) DO UPDATE SET
       persona_description=excluded.persona_description,
       prompt_version=excluded.prompt_version,
       updated_at=datetime('now'),
       updated_by_admin_id=excluded.updated_by_admin_id`,
  )
    .bind(BASE_PROMPT_SUBJECT_ID, 'رفتار پایهٔ معلم هوشمند', text, (existing?.prompt_version ?? 0) + 1, adminUid)
    .run();
  return c.json({ basePrompt: text, isOverridden: true });
});

ai.patch('/admin/ai-teacher/personas/:subjectId', async (c) => {
  if (!(await requireAdminAi(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const subjectId = c.req.param('subjectId');
  const seed = SUBJECT_SEED.find((s) => s.id === subjectId);
  const b = await c.req.json<{ personaDescription?: string }>().catch(() => null);
  const description = String(b?.personaDescription ?? '').trim();
  if (!description) {
    return c.json(fail('BAD_REQUEST', 'توضیح شخصیت نمی‌تواند خالی باشد', 'Persona description required', 'د شخصیت تشریح نشي کولی خالي وي', 'La description du personnage est requise'), 400);
  }
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  const adminId = (payload?.['sub'] as string | undefined) ?? null;
  const existing = await c.env.DB.prepare('SELECT prompt_version FROM ai_teacher_personas WHERE subject_id = ?')
    .bind(subjectId)
    .first<{ prompt_version: number }>();
  const nextVersion = (existing?.prompt_version ?? 0) + 1;
  await c.env.DB.prepare(
    `INSERT INTO ai_teacher_personas (subject_id, subject_name_fa, persona_description, prompt_version, updated_at, updated_by_admin_id)
       VALUES (?, ?, ?, ?, datetime('now'), ?)
     ON CONFLICT(subject_id) DO UPDATE SET
       persona_description=excluded.persona_description,
       prompt_version=excluded.prompt_version,
       updated_at=datetime('now'),
       updated_by_admin_id=excluded.updated_by_admin_id`,
  )
    .bind(subjectId, seed?.nameFa ?? subjectId, description, nextVersion, adminId)
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM ai_teacher_personas WHERE subject_id = ?')
    .bind(subjectId)
    .first<any>();
  return c.json({ persona: personaJson(row) });
});

// ═══════════════ آمار حقیقی معلم هوشمند (برای پنل «مدیریت معلم هوشمند») ═══════
// از همان جدول لاگ سبکِ بالا محاسبه می‌شود — هیچ عدد ساختگی/ثابتی اینجا
// نیست: اگر هنوز هیچ گفتگویی رخ نداده، همه چیز صفر برمی‌گردد (نه یک عدد
// نمایشیِ فرضی)، دقیقاً طبق همان اصل «آمار واقعی» که در بقیهٔ داشبوردهای
// برنامه (مدیر/شاگرد/والد) رعایت شده است.
ai.get('/admin/ai-teacher/stats', async (c) => {
  if (!(await requireAdminAi(c))) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);

  const zero = {
    totalMessages: 0,
    messagesToday: 0,
    activeStudentsToday: 0,
    activeStudentsWeek: 0,
    accuracyPercent: null as number | null,
    totalAnsweredAttempts: 0,
    embeddingCoveragePercent: null as number | null,
    bySubject: [] as { subjectId: string; subjectNameFa: string; messageCount: number }[],
  };

  try {
    const totalRow = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM ai_teacher_chat_logs').first<{ n: number }>();
    const todayRow = await c.env.DB
      .prepare("SELECT COUNT(*) AS n FROM ai_teacher_chat_logs WHERE date(created_at) = date('now')")
      .first<{ n: number }>();
    const activeTodayRow = await c.env.DB
      .prepare(
        "SELECT COUNT(DISTINCT student_id) AS n FROM ai_teacher_chat_logs WHERE date(created_at) = date('now')",
      )
      .first<{ n: number }>();
    const activeWeekRow = await c.env.DB
      .prepare(
        "SELECT COUNT(DISTINCT student_id) AS n FROM ai_teacher_chat_logs WHERE created_at >= datetime('now', '-7 days')",
      )
      .first<{ n: number }>();

    const { results: subjectRows } = await c.env.DB
      .prepare(
        `SELECT l.subject_id AS subject_id, COUNT(*) AS message_count, s.name_fa AS subject_name_fa
           FROM ai_teacher_chat_logs l
           LEFT JOIN subjects s ON s.id = l.subject_id
          GROUP BY l.subject_id
          ORDER BY message_count DESC
          LIMIT 10`,
      )
      .all<{ subject_id: string; message_count: number; subject_name_fa: string | null }>();

    const bySubjectFallback = new Map(SUBJECT_SEED.map((s) => [s.id, s.nameFa]));

    // ── دقت پاسخ‌ها (حلقهٔ یادگیری تطبیقی) — اگر جدول لاگ هنوز خالی/موجود
    // نباشد، null برمی‌گردد (نه صفر گمراه‌کننده، چون صفر یعنی «همه غلط»).
    let accuracyPercent: number | null = null;
    let totalAnsweredAttempts = 0;
    try {
      const accRow = await c.env.DB
        .prepare('SELECT COUNT(*) AS n, SUM(was_correct) AS correct FROM ai_teacher_answer_logs')
        .first<{ n: number; correct: number | null }>();
      totalAnsweredAttempts = accRow?.n ?? 0;
      accuracyPercent =
        totalAnsweredAttempts > 0
          ? Math.round(((accRow?.correct ?? 0) / totalAnsweredAttempts) * 1000) / 10
          : null;
    } catch (_) {
      // جدول هنوز مهاجرت نشده — accuracyPercent همان null باقی می‌ماند.
    }

    // ── پوشش نمایه‌سازی معنایی — چند درصد درس‌های منتشرشده Embedding دارند.
    let embeddingCoveragePercent: number | null = null;
    try {
      const totalLessons = await c.env.DB
        .prepare("SELECT COUNT(*) AS n FROM lessons WHERE status='published'")
        .first<{ n: number }>();
      const embedded = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM lesson_embeddings').first<{ n: number }>();
      embeddingCoveragePercent =
        (totalLessons?.n ?? 0) > 0
          ? Math.round(((embedded?.n ?? 0) / (totalLessons?.n ?? 1)) * 1000) / 10
          : null;
    } catch (_) {
      // بدون تأثیر روی بقیهٔ آمار.
    }

    return c.json({
      totalMessages: totalRow?.n ?? 0,
      messagesToday: todayRow?.n ?? 0,
      activeStudentsToday: activeTodayRow?.n ?? 0,
      activeStudentsWeek: activeWeekRow?.n ?? 0,
      accuracyPercent,
      totalAnsweredAttempts,
      embeddingCoveragePercent,
      bySubject: subjectRows.map((r) => ({
        subjectId: r.subject_id,
        subjectNameFa: r.subject_name_fa ?? bySubjectFallback.get(r.subject_id) ?? r.subject_id,
        messageCount: r.message_count,
      })),
    });
  } catch (_) {
    // جدول لاگ هنوز روی این دیتابیس مهاجرت نشده — به‌جای خطا، صفرِ امن برمی‌گردد
    // (طبق همان اصل Fail-safe که در بقیهٔ Endpointهای آماری برنامه رعایت شده).
    return c.json(zero);
  }
});

export default ai;
// (audit wiring v1 — بخش ۲۰.۳)
