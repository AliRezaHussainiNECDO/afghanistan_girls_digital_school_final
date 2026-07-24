/**
 * lib/essayGrading.ts — نمره‌دهی سؤالات تشریحی با هوش مصنوعی، سمت سرور.
 *
 * قبلاً این تابع فقط داخل `routes/exams.ts` (امتحانات رسمی) تعریف شده بود.
 * با اضافه‌شدن نمره‌دهی سمت سرور برای «تمرین مضامین» (`routes/academy.ts`)،
 * به یک نسخهٔ مشترک منتقل شد تا هر دو مسیر دقیقاً همان منطق (و همان
 * Prompt/قرارداد JSON) را به‌کار ببرند — مطابق درخواست هماهنگیِ کامل بین
 * امتحانات رسمی و تمرین مضامین.
 *
 * قرارداد: خروجی OpenAI-compatible Chat Completions (همان envهای
 * AI_PROVIDER_KEY/AI_PROVIDER_URL/AI_MODEL که در ai.ts هم استفاده می‌شوند).
 */

export type EssayAiBindings = {
  AI_PROVIDER_KEY?: string;
  AI_PROVIDER_URL?: string;
  AI_MODEL?: string;
};

/** فراخوانی خام سرویس AI — متن تمیزشده (بدون کدبلاک ```، بدون متن اضافه
 * قبل از اولین [ یا {) را برمی‌گرداند، بدون JSON.parse. جدا شد تا هم
 * `callAiJson` (پارس سخت‌گیرانه) و هم `callAiJsonArrayLenient` (پارس نرم،
 * برای وقتی پاسخ به دلیل محدودیت `max_tokens` بریده می‌شود) از یک منطق
 * مشترک fetch/پاک‌سازی استفاده کنند. */
async function fetchAiRaw(
  env: EssayAiBindings,
  systemPrompt: string,
  userPrompt: string,
  maxTokens: number,
): Promise<string | null> {
  if (!env.AI_PROVIDER_KEY) return null;
  const url = env.AI_PROVIDER_URL ?? 'https://api.openai.com/v1/chat/completions';
  const model = env.AI_MODEL ?? 'gpt-4o-mini';
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${env.AI_PROVIDER_KEY}` },
    body: JSON.stringify({
      model,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt },
      ],
      temperature: 0.3,
      max_tokens: maxTokens,
    }),
  });
  if (!res.ok) throw new Error(`AI upstream ${res.status}: ${(await res.text()).slice(0, 200)}`);
  const data = (await res.json()) as any;
  let text = String(data?.choices?.[0]?.message?.content ?? '').trim();
  // برخی مدل‌ها JSON را داخل کدبلاک می‌فرستند — پاک‌سازی.
  text = text.replace(/^```(?:json)?\s*/i, '').replace(/\s*```$/, '').trim();
  const start = text.indexOf('[') >= 0 && (text.indexOf('[') < text.indexOf('{') || text.indexOf('{') < 0)
    ? text.indexOf('[')
    : text.indexOf('{');
  if (start > 0) text = text.slice(start);
  return text;
}

async function callAiJson(
  env: EssayAiBindings,
  systemPrompt: string,
  userPrompt: string,
  maxTokens: number,
): Promise<any> {
  const text = await fetchAiRaw(env, systemPrompt, userPrompt, maxTokens);
  if (text === null) return null;
  return JSON.parse(text);
}

/** اشیاء کاملِ سطح‌بالا را از یک متن (که ممکن است ناقص/بریده باشد) استخراج
 * می‌کند — با شمارش عمق آکولاد و نادیده‌گرفتن آکولاد داخل رشته‌ها. اگر
 * پاسخ AI وسط یک شیء قطع شده باشد، همان شیء ناقص رد می‌شود ولی اشیاء کاملِ
 * قبلی حفظ می‌شوند. */
export function extractCompleteJsonObjects(text: string): any[] {
  const out: any[] = [];
  let depth = 0;
  let start = -1;
  let inString = false;
  let escape = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (inString) {
      if (escape) escape = false;
      else if (ch === '\\') escape = true;
      else if (ch === '"') inString = false;
      continue;
    }
    if (ch === '"') {
      inString = true;
      continue;
    }
    if (ch === '{') {
      if (depth === 0) start = i;
      depth++;
    } else if (ch === '}') {
      depth = Math.max(0, depth - 1);
      if (depth === 0 && start >= 0) {
        const candidate = text.slice(start, i + 1);
        try {
          out.push(JSON.parse(candidate));
        } catch {
          // شیء ناقص/نامعتبر — نادیده گرفته می‌شود، ادامه می‌دهیم.
        }
        start = -1;
      }
    }
  }
  return out;
}

/** نسخهٔ «نرم» فراخوانی AI برای پاسخ‌هایی که باید آرایه باشند (مثل تولید
 * چند سؤال با هم): اگر پاسخ کامل باشد، دقیقاً مثل `callAiJson` عمل می‌کند؛
 * اگر به‌خاطر محدودیت `max_tokens` وسط راه بریده شود (JSON.parse معمولی
 * شکست می‌خورد)، به‌جای رد کردن کل درخواست با خطا، هر چه سؤال/شیء کامل تا
 * نقطهٔ قطع تولید شده را نجات می‌دهد. رفع اشکال: قبلاً یک پاسخ بریده باعث
 * شکست کامل (۰ نتیجه) می‌شد؛ مدیر تصور می‌کرد فقط تعداد کمی سؤال قابل
 * ساخت است، در حالی که مشکل واقعی سقف `max_tokens` بود. */
export async function callAiJsonArrayLenient(
  env: EssayAiBindings,
  systemPrompt: string,
  userPrompt: string,
  maxTokens: number,
): Promise<any[]> {
  const text = await fetchAiRaw(env, systemPrompt, userPrompt, maxTokens);
  if (text === null) return [];
  try {
    const parsed = JSON.parse(text);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return extractCompleteJsonObjects(text);
  }
}

/** نمره‌دهی تشریحی با AI — ورودی: سؤالات تشریحی + پاسخ نمونه + پاسخ شاگرد.
 * خروجی: Map از questionId → {score: 0..1, feedback}. در نبود کلید یا خطا،
 * null برمی‌گردد تا تشریحی‌ها از مخرج نمره حذف شوند (نه اینکه ظالمانه صفر
 * حساب شوند و نه رایگان نمرهٔ کامل بگیرند). */
export async function gradeEssaysWithAi(
  env: EssayAiBindings,
  items: Array<{ id: string; text: string; modelAnswer: string; studentAnswer: string }>,
): Promise<Map<string, { score: number; feedback: string }> | null> {
  if (!env.AI_PROVIDER_KEY || items.length === 0) return null;
  try {
    const payload = items.map((q) => ({
      id: q.id,
      question: q.text,
      modelAnswer: q.modelAnswer || '(پاسخ نمونه ثبت نشده — بر اساس صحت علمی نمره بده)',
      studentAnswer: q.studentAnswer,
    }));
    const parsed = await callAiJson(
      env,
      'تو یک معلم عادل مکتب هستی که پاسخ‌های تشریحی شاگردان دختر افغانستان را به زبان دری نمره می‌دهی. فقط JSON خالص برگردان — بدون هیچ متن اضافه.',
      `پاسخ‌های تشریحی زیر را نمره بده. برای هر مورد نمره‌ای بین 0 تا 1 (اعشاری، بر اساس نزدیکی به پاسخ نمونه و صحت علمی) و یک بازخورد یک‌جمله‌ای دری بده.\n` +
        `خروجی: آرایهٔ JSON دقیقاً به شکل [{"id":"...","score":0.8,"feedback":"..."}]\n\n` +
        JSON.stringify(payload),
      1200,
    );
    if (!Array.isArray(parsed)) return null;
    const map = new Map<string, { score: number; feedback: string }>();
    for (const r of parsed) {
      const id = String(r?.id ?? '');
      let score = Number(r?.score);
      if (!id || !Number.isFinite(score)) continue;
      score = Math.max(0, Math.min(1, score));
      map.set(id, { score, feedback: String(r?.feedback ?? '') });
    }
    return map.size > 0 ? map : null;
  } catch {
    return null;
  }
}
