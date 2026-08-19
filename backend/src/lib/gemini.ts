/**
 * lib/gemini.ts — لایهٔ واحد تماس با Gemini API (Google AI Studio، حساب رایگان).
 *
 * چرا این فایل؟ از این پس «منبع مطلق محتوا» خودِ Gemini است (تولید خالص —
 * بدون آپلود PDF/فایل توسط مدیر). چند نقطهٔ بک‌اند (تولید درخت نصاب، تولید
 * متن کامل درس، کار خانگی، چت معلم هوشمند) همگی به Gemini تماس می‌گیرند؛
 * این ماژول سه چیز را یک‌جا و یکسان تضمین می‌کند:
 *
 *   ۱) سازگاری با سهمیهٔ رایگان (Free Tier): مدیریت صریح HTTP 429
 *      (Rate Limit) — سرور هرگز کرش نمی‌کند؛ به‌جای آن نتیجهٔ تایپ‌دار
 *      `rateLimited: true` برمی‌گردد تا هر Endpoint یک پیام خوانا و
 *      محترمانه (قرارداد خطای ۴زبانه) به فرانت‌اند بفرستد و فلاتر آن را با
 *      SnackBar بومی نشان دهد.
 *   ۲) خروجی ساخت‌یافته (ResponseSchema) برای تولید درخت نصاب — دیگر هیچ
 *      تجزیهٔ شکنندهٔ ```json لازم نیست.
 *   ۳) مدل واحد و قابل‌پیکربندی (GEMINI_VISION_MODEL؛ پیش‌فرض همان مدل
 *      پایدار استفاده‌شده در بقیهٔ پروژه).
 */

export type GeminiEnv = {
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
};

export type GeminiOk = { ok: true; text: string };
export type GeminiErr = {
  ok: false;
  /** HTTP status از Gemini (۰ = خطای شبکه/استثنا). */
  status: number;
  /** true یعنی سهمیهٔ رایگان روزانه/دقیقه‌ای تمام شده (HTTP 429). */
  rateLimited: boolean;
  detail: string;
};
export type GeminiResult = GeminiOk | GeminiErr;

export const GEMINI_DEFAULT_MODEL = 'gemini-3.5-flash';

// همان رفع اشکالِ «تولید با AI هیچ‌وقت تمام نمی‌شود» که در essayGrading.ts
// انجام شد، اینجا هم لازم است: از امروز تولید سؤال امتحانات رسمی/آزمون
// فصل/امتحان فاینل هم از همین تابع عبور می‌کند (نگاه کنید به essayGrading.ts)،
// پس این fetch دیگر نباید بدون سقف زمانی بماند.
const GEMINI_FETCH_TIMEOUT_MS = 25_000;

// رفع اشکال «برای متن کوتاه کار می‌کند ولی برای متن یک درس کامل، چند لحظه
// طول می‌کشد و بعد "پخش صوتی در دسترس نیست" می‌دهد»: علت واقعی Timeout بود،
// نه خودِ Gemini. تولید صدا برای یک قطعهٔ ~900حرفی به‌طبیعتِ خودش از یک
// پاسخ کوتاه چت چندین برابر بیشتر طول می‌کشد (خروجی صوتی، نه فقط متن) —
// ۲۵ ثانیهٔ سقفِ چت برای صدا خیلی کم بود. Cloudflare Workers خودش هیچ سقف
// زمانی برای صبر روی fetch بیرونی ندارد (تأیید مستندات رسمی، اوت ۲۰۲۶) —
// این سقف کاملاً خودخواسته بود، پس اینجا سخاوتمندانه‌تر تنظیم شد. سقفِ
// معادل سمت کلاینت هم در ai_voice_remote_datasource.dart بالا برده شد —
// این دو باید همیشه هماهنگ/نزدیک هم بمانند.
//
// رفع اشکالِ دوم (اوت ۲۰۲۶، بعد از شواهدِ `wrangler tail`): حتی بعد از
// محدودکردنِ هر قطعه به حداکثر ۹۰۰حرف، *همهٔ* درخواست‌های TTS — بدون
// استثنا — دقیقاً روی همین سقفِ ۹۰ ثانیه Timeout می‌خوردند
// («TimeoutError: The operation was aborted due to timeout»، status=0،
// یعنی هیچ پاسخی از Google اصلاً نرسید). چون این رفتار برای قطعه‌های
// کوچک هم صد-در-صد تکرار می‌شد، دیگر «طولِ متن» علتِ محتمل نیست — یا
// تولیدِ صدا با این مدل/Endpoint واقعاً کندتر از ۹۰ ثانیه است، یا یک سقفِ
// دیگر (مثلاً محدودیتِ زیرِ-درخواستِ خودِ Cloudflare — مستنداتِ رسمی «بدون
// سقف» می‌گویند، اما چند گزارشِ کاربرانِ دیگر در انجمنِ Cloudflare یک سقفِ
// نانوشتهٔ ۶۰–۹۰ ثانیه‌ای را برای برخی زیر-درخواست‌ها گزارش کرده‌اند) در حالِ
// فعال‌شدن است. این عدد فعلاً بالاتر برده شده تا مشخص شود کدام‌یک است —
// اگر با این سقفِ تازه هم دقیقاً روی همین عدد Timeout بخورد، یعنی سقفِ
// واقعی جای دیگری (نه اینجا) تحمیل می‌شود و باید مسیرِ دیگری (مثلاً
// Streaming API) دنبال شود؛ اگر جایی بینِ ۹۰ تا این عدد موفق شود، یعنی
// Gemini واقعاً همین‌قدر کند است. لاگِ elapsedMs زیر دقیقاً همین را نشان
// می‌دهد.
const GEMINI_TTS_FETCH_TIMEOUT_MS = 170_000;

/**
 * قواعد سخت‌گیرانهٔ کیفیت متن دری/پشتو — ضد بریدگی و جابجایی کلمات.
 *
 * چرا: در خروجی‌های طولانی، مدل گاهی کلمات را می‌شکند («عریف» به‌جای «تعریف»)،
 * کاراکترهای کنترل جهت نامرئی (LRM/RLM/Embedding) تزریق می‌کند یا فاصله‌های
 * متوالی می‌گذارد که چیدمان RTL فلاتر را به هم می‌ریزد. این بلوک به انتهای
 * تمام پرامپت‌های تولید محتوا (متن درس، درخت کتاب، کار خانگی، چت معلم)
 * افزوده می‌شود و کنارش [sanitizeDariText] به‌صورت قطعی (Deterministic)
 * خروجی را پاک‌سازی می‌کند — دفاع دولایه.
 */
export const DARI_OUTPUT_RULES =
  `\n\nقواعد سخت‌گیرانهٔ نگارش خروجی (تخطی مطلقاً ممنوع):\n` +
  `• هر کلمه را کامل و پیوسته بنویس؛ هرگز حروف یک کلمه را جدا نکن و هیچ کلمه‌ای را در انتهای سطر نشکن (مثلاً «تعریف» هرگز «ت عریف» یا «عریف» نشود).\n` +
  `• املای تمام کلمات دری/پشتو باید کاملاً دقیق و استاندارد باشد؛ برای پیوندهای صرفی فقط نیم‌فاصلهٔ استاندارد (ZWNJ) به کار ببر (می‌روم، کتاب‌ها).\n` +
  `• هیچ کاراکتر نامرئی یا کنترل جهت (LRM/RLM/LRE/RLE/PDF/Isolate) و هیچ Tab یا فاصلهٔ متوالی (بیش از یک فاصله پشت‌سرهم) در خروجی نباشد.\n` +
  `• بین کلمات دقیقاً یک فاصلهٔ ساده؛ بین پاراگراف‌ها فقط یک خط خالی؛ مارک‌داون تمیز و استاندارد (سرخط با #، فهرست با -).\n` +
  `• عدد/عبارت انگلیسی یا فرمول را هرگز بدون فاصله به کلمهٔ دری نچسبان — قبل و بعد آن دقیقاً یک فاصله بگذار.\n` +
  `• فرمول‌های ریاضی/کیمیا را با نویسه‌های استاندارد یونیکد بنویس ( × ÷ − √ ² ³ π ≤ ≥ ≠ ) و کسر را به شکل a/b؛ از LaTeX خام ($ یا \\frac) استفاده نکن چون نمایشگر اپ آن را پشتیبانی نمی‌کند.`;

/**
 * پاک‌سازی قطعی متن تولیدی — لایهٔ دوم دفاع (مستقل از فرمان‌برداری مدل):
 * حذف کاراکترهای کنترل جهت و نامرئی مخرب (به‌جز ZWNJ نیم‌فاصلهٔ مجاز)،
 * ادغام فاصله‌های متوالی، و حذف فاصلهٔ آویزان انتهای سطرها.
 * روی Markdown امن است (بلاک‌های کد چندخطی در محتوای درسی ما جدول/متن‌اند
 * و فاصله‌های متوالی معناداری ندارند).
 */
export function sanitizeDariText(text: string): string {
  return (
    text
      // کاراکترهای کنترل جهت و نامرئی: ZWSP (200B)، LRM/RLM (200E/200F)،
      // LRE..RLO (202A-202E)، Word Joiner (2060)، Isolates (2066-2069)،
      // BOM (FEFF). نکته: نیم‌فاصلهٔ مجاز ZWNJ (200C) عمداً حفظ می‌شود.
      .replace(/[\u200B\u200E\u200F\u202A-\u202E\u2060\u2066-\u2069\uFEFF]/g, '')
      // Tab و فاصله‌های اگزوتیک (NBSP، فاصله‌های تایپوگرافیک، فاصلهٔ تمام‌عرض) → فاصلهٔ ساده
      .replace(/[\t\u00A0\u2000-\u200A\u3000]/g, ' ')
      // فاصله‌های متوالی → یک فاصله (خطوط جدید دست نمی‌خورند)
      .replace(/ {2,}/g, ' ')
      // فاصلهٔ آویزان انتهای سطر
      .replace(/ +$/gm, '')
      // بیش از یک خط خالی متوالی → یک خط خالی
      .replace(/\n{3,}/g, '\n\n')
      .trim()
  );
}

/** بدنهٔ خطای استاندارد ۴زبانه برای «سهمیهٔ رایگان تمام شد» — یکسان در همهٔ Endpointها. */
export function rateLimitFailBody() {
  return {
    success: false,
    error: {
      code: 'AI_RATE_LIMITED',
      message_fa:
        'سهمیهٔ رایگان هوش مصنوعی برای امروز/این لحظه به پایان رسیده است. لطفاً چند دقیقهٔ دیگر دوباره تلاش کنید. 🌸',
      message_en: 'The free AI quota is temporarily exhausted. Please try again in a few minutes.',
      message_ps: 'د مصنوعي هوښیارتیا وړیا ونډه د اوس لپاره پای ته ورسېده. مهرباني وکړئ څو دقیقې وروسته بیا هڅه وکړئ.',
      message_fr: "Le quota gratuit d'IA est temporairement épuisé. Veuillez réessayer dans quelques minutes.",
    },
  };
}

/**
 * یک تماس generateContent — کاملاً Fail-safe (هرگز throw نمی‌کند).
 * `responseSchema` که داده شود، responseMimeType خودکار JSON می‌شود و متن
 * برگشتی مستقیماً قابل JSON.parse است.
 */
export async function geminiGenerate(
  env: GeminiEnv,
  opts: {
    prompt: string;
    systemInstruction?: string;
    responseSchema?: unknown;
    temperature?: number;
    maxOutputTokens?: number;
    /** minimal برای تولید متن ساده — توکن تفکر از سقف خروجی کم می‌شود. */
    thinkingLevel?: 'minimal' | 'low' | 'medium' | 'high';
  },
): Promise<GeminiResult> {
  if (!env.GEMINI_API_KEY) {
    return { ok: false, status: 0, rateLimited: false, detail: 'GEMINI_API_KEY not configured' };
  }
  const model = env.GEMINI_VISION_MODEL ?? GEMINI_DEFAULT_MODEL;
  const generationConfig: Record<string, unknown> = {
    temperature: opts.temperature ?? 0.4,
    maxOutputTokens: opts.maxOutputTokens ?? 8192,
    thinkingConfig: { thinkingLevel: opts.thinkingLevel ?? 'minimal' },
  };
  if (opts.responseSchema) {
    generationConfig['responseMimeType'] = 'application/json';
    generationConfig['responseSchema'] = opts.responseSchema;
  }
  const body: Record<string, unknown> = {
    contents: [{ parts: [{ text: opts.prompt }] }],
    generationConfig,
  };
  if (opts.systemInstruction) {
    body['systemInstruction'] = { parts: [{ text: opts.systemInstruction }] };
  }
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(GEMINI_FETCH_TIMEOUT_MS),
      },
    );
    if (!res.ok) {
      const detail = (await res.text().catch(() => '')).slice(0, 500);
      // 429 = Rate Limit سهمیهٔ رایگان؛ برخی خطاهای سهمیه با 403 و پیام
      // RESOURCE_EXHAUSTED هم می‌آیند — هر دو «قفل موقت» حساب می‌شوند.
      const rateLimited = res.status === 429 || detail.includes('RESOURCE_EXHAUSTED');
      console.error(`[gemini] HTTP ${res.status} — ${detail}`);
      return { ok: false, status: res.status, rateLimited, detail };
    }
    const data = (await res.json()) as any;
    const text: string =
      data?.candidates?.[0]?.content?.parts?.map((p: any) => p.text ?? '').join('') ?? '';
    if (!text.trim()) {
      return { ok: false, status: res.status, rateLimited: false, detail: 'empty reply' };
    }
    return { ok: true, text };
  } catch (err: any) {
    console.error('[gemini] network/exception —', err);
    return { ok: false, status: 0, rateLimited: false, detail: String(err).slice(0, 300) };
  }
}

/**
 * بسته‌بندی PCM خام (خروجی مستقیم Gemini TTS، بدون هیچ هدری) در یک کانتینر
 * WAV استاندارد ۱۶بیتی — چون بدون این پوشش، هیچ پخش‌کنندهٔ صوتی سمت کلاینت
 * (audioplayers) این بایت‌های خام را نمی‌شناسد/پخش نمی‌کند.
 */
function pcmToWav(pcm: Uint8Array, sampleRate: number, channels = 1, bitsPerSample = 16): Uint8Array {
  const blockAlign = channels * (bitsPerSample / 8);
  const byteRate = sampleRate * blockAlign;
  const buffer = new ArrayBuffer(44 + pcm.length);
  const view = new DataView(buffer);
  const writeStr = (offset: number, s: string) => {
    for (let i = 0; i < s.length; i++) view.setUint8(offset + i, s.charCodeAt(i));
  };
  writeStr(0, 'RIFF');
  view.setUint32(4, 36 + pcm.length, true);
  writeStr(8, 'WAVE');
  writeStr(12, 'fmt ');
  view.setUint32(16, 16, true); // اندازهٔ بلوک fmt برای PCM
  view.setUint16(20, 1, true); // فرمت صوتی = PCM
  view.setUint16(22, channels, true);
  view.setUint32(24, sampleRate, true);
  view.setUint32(28, byteRate, true);
  view.setUint16(32, blockAlign, true);
  view.setUint16(34, bitsPerSample, true);
  writeStr(36, 'data');
  view.setUint32(40, pcm.length, true);
  new Uint8Array(buffer, 44).set(pcm);
  return new Uint8Array(buffer);
}

export type GeminiTtsResult =
  | { ok: true; wav: Uint8Array }
  | { ok: false; status: number; detail: string };

/**
 * صدای معلم AI با مدل مولد Gemini TTS — مسیر اصلیِ صدا (بخش ۲۱.۴ سند،
 * به‌روزشده): چرا Gemini و نه Azure/OpenAI؟
 *
 *   ۱) هیچ ارائه‌دهندهٔ ابری بزرگی (Azure، Google Cloud TTS استاندارد،
 *      OpenAI) صدای اختصاصی دری افغانستان (fa-AF) ندارد — همه فقط فارسیِ
 *      ایران (fa-IR) دارند (تأیید دوباره، اوت ۲۰۲۶). اما Gemini TTS برخلاف
 *      آن‌ها یک بانکِ صدای ثابت نیست؛ یک مدل مولد قابل‌هدایت با متن است —
 *      یعنی می‌توان مستقیماً در متن ارسالی از آن خواست با «لهجهٔ دری
 *      افغانستان» بخواند. نتیجه تضمینیِ صددرصد افغانی نیست (هیچ مدلی روی
 *      دادهٔ صوتی واقعیِ دری افغانستان آموزش ندیده) ولی نزدیک‌ترین تلاش
 *      واقعاً ممکن است.
 *   ۲) از همان GEMINI_API_KEY موجود و فعال (برای نصاب/نمره‌دهی) استفاده
 *      می‌کند — سطح رایگان واقعی دارد، نیازی به اشتراک/کارت بانکی جدید نیست
 *      (برخلاف Azure که اشتراکش می‌تواند غیرفعال شود — دقیقاً همان مشکلی که
 *      رخ داد).
 *
 * خروجی: PCM خام ۱۶بیتی تک‌کاناله (نرخ نمونه از mimeType پاسخ خوانده
 * می‌شود، پیش‌فرض مستند ۲۴کیلوهرتز) — اینجا در WAV بسته‌بندی می‌شود تا
 * صدازننده (routes/ai.ts) مستقیم آن را با Content-Type: audio/wav برگرداند.
 */
export async function geminiSynthesizeSpeech(
  env: GeminiEnv & { GEMINI_TTS_MODEL?: string; GEMINI_TTS_VOICE?: string },
  text: string,
): Promise<GeminiTtsResult> {
  if (!env.GEMINI_API_KEY) {
    return { ok: false, status: 0, detail: 'GEMINI_API_KEY not configured' };
  }
  const model = env.GEMINI_TTS_MODEL ?? 'gemini-2.5-flash-preview-tts';
  // صدای پیش‌فرض «Sulafat» — طبق کاتالوگ رسمی صداهای Gemini، برچسبش «Warm»
  // (گرم) است؛ نزدیک‌ترین گزینه به لحن یک معلم مهربان.
  const voice = env.GEMINI_TTS_VOICE ?? 'Sulafat';
  // دستور لهجه/لحن مستقیماً در متن ارسالی — طبق مستندات رسمی Gemini TTS این
  // روش تعیینِ سبک است؛ خودِ مدل جملهٔ دستور را با صدای بلند نمی‌خواند، فقط
  // طبق آن، لحنِ متنِ اصلی را می‌سازد.
  const styledText =
    'با لهجهٔ دری افغانستان (نه فارسیِ ایران)، با صدای گرم، آرام و مهربانِ یک معلم زن افغان، ' +
    'واضح و شمرده این متن را برای یک شاگرد دخترِ مکتب بخوان:\n' +
    text;
  // لاگِ elapsedMs (برای هر دو مسیرِ موفق/ناموفق) — دقیقاً همان چیزی که برای
  // تشخیصِ «Gemini واقعاً کند است یا یک سقفِ دیگر در حالِ فعال‌شدن است» لازم
  // است؛ نگاه کنید به توضیحِ بالای GEMINI_TTS_FETCH_TIMEOUT_MS.
  const startedAt = Date.now();
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: styledText }] }],
          generationConfig: {
            responseModalities: ['AUDIO'],
            speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } } },
          },
        }),
        signal: AbortSignal.timeout(GEMINI_TTS_FETCH_TIMEOUT_MS),
      },
    );
    const elapsedMs = Date.now() - startedAt;
    if (!res.ok) {
      const detail = (await res.text().catch(() => '')).slice(0, 500);
      console.error(`[gemini-tts] HTTP ${res.status} — chars=${text.length} elapsedMs=${elapsedMs} — ${detail}`);
      return { ok: false, status: res.status, detail };
    }
    const data = (await res.json()) as any;
    const part = data?.candidates?.[0]?.content?.parts?.[0];
    const b64: string | undefined = part?.inlineData?.data;
    if (!b64) {
      console.error(`[gemini-tts] no inlineData.data — chars=${text.length} elapsedMs=${elapsedMs}`);
      return { ok: false, status: res.status, detail: 'no audio in response' };
    }
    const bin = atob(b64);
    const pcm = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) pcm[i] = bin.charCodeAt(i);
    const mimeType: string = part?.inlineData?.mimeType ?? '';
    const rateMatch = /rate=(\d+)/.exec(mimeType);
    const sampleRate = rateMatch ? parseInt(rateMatch[1], 10) : 24000;
    console.error(`[gemini-tts] ok — chars=${text.length} elapsedMs=${elapsedMs}`);
    return { ok: true, wav: pcmToWav(pcm, sampleRate) };
  } catch (err: any) {
    const elapsedMs = Date.now() - startedAt;
    console.error(`[gemini-tts] network/exception — chars=${text.length} elapsedMs=${elapsedMs} —`, err);
    return { ok: false, status: 0, detail: String(err).slice(0, 300) };
  }
}

/**
 * تولید تصویر آموزشی با تصویرساز داخلی Gemini (مدل تصویری). خروجی بایت‌های
 * PNG یا null (هر خطا/نبود سهمیه → null؛ صدازننده Placeholder می‌گذارد).
 */
export async function geminiGenerateImage(
  env: GeminiEnv & { GEMINI_IMAGE_MODEL?: string },
  description: string,
): Promise<Uint8Array | null> {
  if (!env.GEMINI_API_KEY) return null;
  const model = env.GEMINI_IMAGE_MODEL ?? 'gemini-2.5-flash-image';
  try {
    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [
            {
              parts: [
                {
                  text:
                    'یک تصویر آموزشی سادهٔ کتاب درسی مکتب، تمیز و واضح، با پس‌زمینهٔ روشن و بدون متن اضافه بساز: ' +
                    description,
                },
              ],
            },
          ],
          generationConfig: { responseModalities: ['IMAGE'] },
        }),
      },
    );
    if (!res.ok) {
      console.error(`[gemini-image] HTTP ${res.status}`);
      return null;
    }
    const data = (await res.json()) as any;
    const parts: any[] = data?.candidates?.[0]?.content?.parts ?? [];
    for (const p of parts) {
      const b64 = p?.inlineData?.data;
      if (typeof b64 === 'string' && b64.length > 0) {
        const bin = atob(b64);
        const bytes = new Uint8Array(bin.length);
        for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
        return bytes;
      }
    }
    return null;
  } catch (err) {
    console.error('[gemini-image] exception —', err);
    return null;
  }
}
