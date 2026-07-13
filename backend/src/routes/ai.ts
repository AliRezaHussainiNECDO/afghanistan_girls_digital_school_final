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

function fail(code: string, fa: string, en: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en } };
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
    return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  }
  if (!c.env.AI_PROVIDER_KEY) {
    // کلید تنظیم نشده → کلاینت (FallbackAiEngine) خودکار به موتور محلی برمی‌گردد.
    return c.json(
      fail('AI_NOT_CONFIGURED', 'موتور هوش مصنوعی سرور پیکربندی نشده است', 'AI provider not configured'),
      503,
    );
  }

  const body = await c.req.json<{ messages?: Array<{ role: string; content: string }> }>().catch(() => null);
  const messages = body?.messages;
  if (!messages || messages.length === 0) {
    return c.json(fail('BAD_REQUEST', 'پیام نامعتبر', 'Invalid messages'), 400);
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
      return c.json(
        { ...fail('AI_UPSTREAM_ERROR', 'خطا از سرویس هوش مصنوعی', 'AI upstream error'), detail: text.slice(0, 300) },
        502,
      );
    }
    const data = (await res.json()) as any;
    const reply = data?.choices?.[0]?.message?.content?.trim() ?? '';
    if (!reply) {
      return c.json(fail('AI_EMPTY', 'پاسخ خالی از سرویس هوش مصنوعی', 'Empty AI reply'), 502);
    }
    return c.json({ reply });
  } catch (e: any) {
    return c.json(fail('AI_NETWORK', 'اتصال به سرویس هوش مصنوعی ناموفق بود', 'AI network error'), 502);
  }
});

// ═══════════════════════ TTS — متن به گفتار (صدای خانم دری) ═══════════════════
// اولویت با Azure (صدای اصیل دری افغانستان: prs-AF-FatimaNeural)؛ در نبود آن،
// TTS سازگار با OpenAI (صدای خانم مثل «shimmer/nova») به‌عنوان جایگزین.
// خروجی: بایت‌های audio/mpeg (استریم). در نبود هر دو → 503 (کلاینت Fail-safe).

ai.post('/ai-teacher/tts', async (c) => {
  if (!(await requireUser(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  const body = await c.req.json<{ text?: string }>().catch(() => null);
  const text = (body?.text ?? '').trim();
  if (!text) return c.json(fail('BAD_REQUEST', 'متن خالی است', 'Empty text'), 400);

  // ۱) Azure — صدای خانم دری (prs-AF). قابل‌تنظیم با AZURE_TTS_VOICE اگر نام
  //    صدا متفاوت بود (مثلاً prs-AF-LatifaNeural).
  if (c.env.AZURE_TTS_KEY && c.env.AZURE_TTS_REGION) {
    const voice = c.env.AZURE_TTS_VOICE ?? 'prs-AF-FatimaNeural';
    const ssml =
      `<speak version='1.0' xml:lang='prs-AF'>` +
      `<voice xml:lang='prs-AF' name='${voice}'>${escapeXml(text)}</voice></speak>`;
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
      return c.json(fail('TTS_UPSTREAM', 'خطا از سرویس صدا', 'TTS upstream error'), 502);
    } catch (_) {
      return c.json(fail('TTS_NETWORK', 'اتصال به سرویس صدا ناموفق بود', 'TTS network error'), 502);
    }
  }

  return c.json(fail('TTS_NOT_CONFIGURED', 'سرویس صدا پیکربندی نشده است', 'TTS not configured'), 503);
});

// ═══════════════════════ STT — گفتار به متن (Whisper) ════════════════════════
// بدنه = بایت‌های صوتی خام (audio/m4a). خروجی: {text}. زبان: دری/فارسی.

ai.post('/ai-teacher/stt', async (c) => {
  if (!(await requireUser(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized'), 401);
  if (!c.env.AI_PROVIDER_KEY) {
    return c.json(fail('STT_NOT_CONFIGURED', 'سرویس تبدیل گفتار پیکربندی نشده است', 'STT not configured'), 503);
  }
  const bytes = await c.req.arrayBuffer();
  if (bytes.byteLength === 0) {
    return c.json(fail('BAD_REQUEST', 'فایل صوتی خالی است', 'Empty audio'), 400);
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
      return c.json(fail('STT_UPSTREAM', 'خطا از سرویس تبدیل گفتار', 'STT upstream error'), 502);
    }
    const data = (await res.json()) as any;
    return c.json({ text: (data?.text ?? '').trim() });
  } catch (_) {
    return c.json(fail('STT_NETWORK', 'اتصال به سرویس تبدیل گفتار ناموفق بود', 'STT network error'), 502);
  }
});

export default ai;
