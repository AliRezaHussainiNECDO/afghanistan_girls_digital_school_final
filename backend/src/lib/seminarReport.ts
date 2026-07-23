/**
 * lib/seminarReport.ts — تولید گزارش آرشیف سمینار با هوش مصنوعی.
 *
 * وقتی یک سمینار به‌طور خودکار آرشیف می‌شود (رجوع کنید به `sweepEndedSeminars`
 * در `routes/seminars.ts`)، این ماژول یک خلاصهٔ ساختاریافتهٔ دری از
 * فراداده‌های واقعیِ همان سمینار می‌سازد. چون پروژه فعلاً رونوشت/ضبط صوتیِ
 * خودِ جلسه را ذخیره نمی‌کند، گزارش بر پایهٔ فراداده (عنوان، توضیح، استاد،
 * مخاطب، زمان‌بندی، تعداد ثبت‌نامی/ظرفیت) است — نه تحلیل محتوای واقعیِ
 * گفتگوی جلسه. همیشه یک رشتهٔ غیرخالی برمی‌گرداند (حتی بدون کلید AI روی
 * سرور) تا آرشیف هرگز خالی نماند.
 */
import { geminiGenerate, sanitizeDariText, DARI_OUTPUT_RULES } from './gemini';

export type SeminarReportEnv = {
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
  AI_PROVIDER_KEY?: string;
  AI_PROVIDER_URL?: string;
  AI_MODEL?: string;
};

export type SeminarReportInput = {
  title: string;
  description: string;
  instructorName: string;
  audience: 'students' | 'parents';
  scheduledStart: string;
  durationMinutes: number;
  registeredCount: number;
  capacity: number | null;
};

export async function generateSeminarArchiveReport(
  env: SeminarReportEnv,
  input: SeminarReportInput,
): Promise<string> {
  const attendanceRate =
    input.capacity && input.capacity > 0
      ? Math.round((input.registeredCount / input.capacity) * 100)
      : null;
  const fallback = buildFallbackReport(input, attendanceRate);

  const prompt =
    `یک گزارش کوتاه و حرفه‌ای (حداکثر ۱۲۰ کلمه) به زبان دری برای آرشیف یک سمینار مکتب دیجیتال دخترانه بنویس. ` +
    `فقط بر اساس اطلاعات زیر بنویس (چیزی را که داده نشده حدس نزن):\n` +
    `عنوان: ${input.title}\nتوضیح: ${input.description || '—'}\nاستاد: ${input.instructorName || '—'}\n` +
    `مخاطب: ${input.audience === 'parents' ? 'والدین' : 'شاگردان'}\n` +
    `زمان برگزاری: ${input.scheduledStart}\nمدت: ${input.durationMinutes} دقیقه\n` +
    `تعداد ثبت‌نامی: ${input.registeredCount}${input.capacity ? ` از ظرفیت ${input.capacity}` : ''}\n\n` +
    `گزارش باید شامل این سه بخش کوتاه باشد: خلاصهٔ موضوع سمینار، ارزیابیِ کوتاهِ میزان استقبال (بر اساس تعداد ثبت‌نامی)، و یک پیشنهاد عملی برای سمینار بعدی.` +
    DARI_OUTPUT_RULES;

  try {
    if (env.GEMINI_API_KEY) {
      const result = await geminiGenerate(env, { prompt, temperature: 0.5, maxOutputTokens: 500 });
      if (result.ok) return sanitizeDariText(result.text);
      return fallback;
    }

    if (env.AI_PROVIDER_KEY) {
      const url = env.AI_PROVIDER_URL ?? 'https://api.openai.com/v1/chat/completions';
      const model = env.AI_MODEL ?? 'gpt-4o-mini';
      const res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${env.AI_PROVIDER_KEY}` },
        body: JSON.stringify({
          model,
          messages: [{ role: 'user', content: prompt }],
          temperature: 0.5,
          max_tokens: 500,
        }),
      });
      if (res.ok) {
        const data = (await res.json()) as any;
        const text = data?.choices?.[0]?.message?.content;
        if (typeof text === 'string' && text.trim()) return sanitizeDariText(text);
      }
      return fallback;
    }
  } catch (err) {
    console.error('[seminarReport] AI call failed —', err);
    return fallback;
  }

  return fallback;
}

function buildFallbackReport(input: SeminarReportInput, attendanceRate: number | null): string {
  const parts = [
    `سمینار «${input.title}» توسط ${input.instructorName || 'استاد'} برای ${
      input.audience === 'parents' ? 'والدین' : 'شاگردان'
    } برگزار شد.`,
    `مدت برگزاری: ${input.durationMinutes} دقیقه.`,
    input.registeredCount > 0
      ? `تعداد ثبت‌نامی: ${input.registeredCount}${input.capacity ? ` از ظرفیت ${input.capacity}` : ''}${
          attendanceRate != null ? ` (حدود ${attendanceRate}٪ ظرفیت)` : ''
        }.`
      : 'هیچ ثبت‌نامی برای این سمینار ثبت نشده بود.',
    'این گزارش به‌صورت خودکار و بدون هوش مصنوعی (به‌دلیل نبود کلید سرویس AI روی سرور) از فراداده‌های سمینار ساخته شده است.',
  ];
  return parts.join(' ');
}
