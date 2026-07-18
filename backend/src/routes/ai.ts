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

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  AI_PROVIDER_KEY?: string;
  AI_PROVIDER_URL?: string;
  AI_MODEL?: string;
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

ai.post('/ai-teacher/chat', async (c) => {
  const payload = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!payload?.['sub']) {
    return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  }
  if (!c.env.AI_PROVIDER_KEY) {
    // کلید تنظیم نشده → کلاینت (FallbackAiEngine) خودکار به موتور محلی برمی‌گردد.
    return c.json(
      fail('AI_NOT_CONFIGURED', 'موتور هوش مصنوعی سرور پیکربندی نشده است', 'AI provider not configured', 'د سرور د مصنوعي هوښیارتیا انجن تنظیم شوی نه دی', 'Le moteur d\'IA du serveur n\'est pas configuré'),
      503,
    );
  }

  const body = await c.req
    .json<{ messages?: Array<{ role: string; content: string }>; subjectId?: string }>()
    .catch(() => null);
  const messages = body?.messages;
  if (!messages || messages.length === 0) {
    return c.json(fail('BAD_REQUEST', 'پیام نامعتبر', 'Invalid messages', 'ناسم پیغام', 'Messages invalides'), 400);
  }
  const subjectId = String(body?.subjectId ?? 'unknown').trim() || 'unknown';

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

// ═══════════════════════ STT — گفتار به متن (Whisper) ════════════════════════
// بدنه = بایت‌های صوتی خام (audio/m4a). خروجی: {text}. زبان: دری/فارسی.

ai.post('/ai-teacher/stt', async (c) => {
  if (!(await requireUser(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  if (!c.env.AI_PROVIDER_KEY) {
    return c.json(fail('STT_NOT_CONFIGURED', 'سرویس تبدیل گفتار پیکربندی نشده است', 'STT not configured', 'د خبرو بدلون خدمت تنظیم شوی نه دی', 'Le service de reconnaissance vocale n\'est pas configuré'), 503);
  }
  const bytes = await c.req.arrayBuffer();
  if (bytes.byteLength === 0) {
    return c.json(fail('BAD_REQUEST', 'فایل صوتی خالی است', 'Empty audio', 'غږیز فایل تش دی', 'Le fichier audio est vide'), 400);
  }
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
    if (!res.ok) {
      return c.json(fail('STT_UPSTREAM', 'خطا از سرویس تبدیل گفتار', 'STT upstream error', 'د خبرو بدلون له خدمت نه تېروتنه', 'Erreur du service de reconnaissance vocale'), 502);
    }
    const data = (await res.json()) as any;
    return c.json({ text: (data?.text ?? '').trim() });
  } catch (_) {
    return c.json(fail('STT_NETWORK', 'اتصال به سرویس تبدیل گفتار ناموفق بود', 'STT network error', 'د خبرو بدلون له خدمت سره اړیکه ونشوه', 'Échec de la connexion au service de reconnaissance vocale'), 502);
  }
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

const SUBJECT_SEED: { id: string; nameFa: string }[] = [
  { id: 'math', nameFa: 'ریاضی' },
  { id: 'physics', nameFa: 'فزیک' },
  { id: 'chemistry', nameFa: 'کیمیا' },
  { id: 'biology', nameFa: 'بیولوژی' },
  { id: 'dari', nameFa: 'دری' },
  { id: 'pashto', nameFa: 'پشتو' },
  { id: 'english', nameFa: 'انگلیسی' },
  { id: 'history', nameFa: 'تاریخ' },
  { id: 'geography', nameFa: 'جغرافیه' },
  { id: 'islamic_studies', nameFa: 'مضامین اسلامی' },
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
