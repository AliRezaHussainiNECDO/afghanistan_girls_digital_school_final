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
      { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) },
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
