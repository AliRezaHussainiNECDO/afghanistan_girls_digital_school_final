/**
 * lib/aiLessonContent.ts — «تولید خالص محتوا با هوش مصنوعی» (Pure AI Generation).
 *
 * منبع مطلق محتوا از این پس خودِ Gemini است: مدیر فقط (صنف + مضمون) را انتخاب
 * و «تولید هوشمند» را می‌زند؛ Gemini با اتکا به دانش خود از نصاب تعلیمی معارف
 * افغانستان، درخت کامل کتاب (فصل‌ها → درس‌ها) را با ResponseSchema می‌سازد
 * (routes/aiCurriculum.ts). برای سازگاری با سهمیهٔ رایگان (Free Tier)، متن
 * کامل هر درس در همان لحظه ساخته نمی‌شود (یک کتاب = ده‌ها تماس = اتمام فوری
 * سهمیه)؛ به‌جای آن هر درس با یک «نشانگر در انتظار» + خلاصهٔ یک‌خطی ذخیره
 * می‌شود و متن کامل Markdown آن **اولین باری که شاگردی درس را باز می‌کند**
 * (Lazy) با یک تماس تولید و برای همیشه در `lessons.content_body` ذخیره
 * می‌شود — تماس‌ها در طول زمان پخش می‌شوند و از سهمیهٔ روزانه عبور نمی‌کنند.
 *
 * 🚨 خط قرمز: این فایل به هیچ‌وجه به منطق امتیازدهی/پیشرفت/کار خانگی دست
 * نمی‌زند — فقط محتوای `content_body` را پر می‌کند؛ شناسه‌های درس/فصل ثابت
 * می‌مانند تا زنجیرهٔ «یاد گرفتم ← کار خانگی» دقیقاً مثل قبل کار کند.
 */

import { geminiGenerate, sanitizeDariText, DARI_OUTPUT_RULES, type GeminiEnv } from './gemini';

/** نشانگر «متن کامل این درس هنوز تولید نشده» در ابتدای content_body. */
export const AI_PENDING_MARKER = '<!--AI_PENDING-->';

export function isPendingAiContent(content: string | null | undefined): boolean {
  return (content ?? '').startsWith(AI_PENDING_MARKER);
}

/** خلاصهٔ ذخیره‌شده کنار نشانگر (برای Prompt تولید متن کامل). */
export function pendingSummary(content: string): string {
  return content.slice(AI_PENDING_MARKER.length).trim();
}

export type LessonMeta = {
  id: string;
  titleFa: string;
  contentBody: string;
  chapterTitleFa: string;
  subjectNameFa: string;
  gradeNumber: number;
};

export type EnsureContentResult =
  | { status: 'ready'; content: string }
  | { status: 'rate_limited' }
  | { status: 'failed' };

/**
 * اگر متن کامل درس هنوز تولید نشده، همین حالا با Gemini تولید، تگ‌های تصویر
 * را بازنویسی و در دیتابیس ذخیره می‌کند (تولید فقط یک‌بار در عمر هر درس).
 *
 * `origin` = ریشهٔ عمومی همین Worker (از URL درخواست جاری) — برای ساختن
 * لینک مطلق تصاویر `/api/v1/ai-images/...` که فلاتر بدون Header بتواند لود کند.
 */
export async function ensureLessonContent(
  env: GeminiEnv & { DB: D1Database },
  lesson: LessonMeta,
  origin: string,
): Promise<EnsureContentResult> {
  if (!isPendingAiContent(lesson.contentBody)) {
    return { status: 'ready', content: lesson.contentBody };
  }
  const summary = pendingSummary(lesson.contentBody);

  const prompt =
    `متن کامل آموزشی درس زیر را از نصاب تعلیمی رسمی معارف افغانستان، از صفر و کامل بنویس:\n` +
    `• صنف: ${lesson.gradeNumber}\n` +
    `• مضمون: ${lesson.subjectNameFa}\n` +
    `• فصل: ${lesson.chapterTitleFa}\n` +
    `• عنوان درس: ${lesson.titleFa}\n` +
    (summary ? `• خلاصهٔ سرفصل: ${summary}\n` : '') +
    `\nقواعد نگارش (دقیقاً رعایت شود):\n` +
    `۱. خروجی فقط Markdown تمیز فارسی/دری باشد — با سرخط‌ها (##)، فهرست‌ها، و در صورت نیاز جدول. هیچ متن اضافه خارج از خود درس ننویس.\n` +
    `۲. مخاطب یک دانش‌آموز دختر بازمانده از تحصیل است که این درس را بدون معلم حضوری می‌خواند: لحن گام‌به‌گام، گرم، محترمانه و انگیزشی.\n` +
    `۳. تمام مثال‌ها، نام‌ها و سناریوها کاملاً بومی افغانستان باشند (ولایات مثل هرات/بامیان/بلخ، زراعت، بازار محلی، داستان‌های انگیزشی دختران معارف).\n` +
    `۴. ساختار: مقدمهٔ کوتاه ← بدنهٔ آموزشی گام‌به‌گام با مثال حل‌شده ← بخش پایانی «## ختم درس» شامل جمع‌بندی، فرمول‌ها/پاسخ‌های کلیدی و ۲-۳ سؤال تمرینی.\n` +
    `۵. اگر (و فقط اگر) فهم درس به شکل/تصویر نیاز دارد (اشکال هندسی، آزمایش فزیک، ساختار بیولوژی)، حداکثر ۲ تصویر را دقیقاً با این قالب درج کن:\n` +
    `   ![شرح کوتاه فارسی](ai-image://short-english-description-with-dashes)\n` +
    `۶. طول مناسب: حدود ۴۰۰ تا ۸۰۰ کلمه.` +
    DARI_OUTPUT_RULES;

  const result = await geminiGenerate(env, {
    prompt,
    temperature: 0.5,
    maxOutputTokens: 8192,
    thinkingLevel: 'minimal',
  });

  if (!result.ok) {
    return result.rateLimited ? { status: 'rate_limited' } : { status: 'failed' };
  }

  // پاک‌سازی قطعی کیفیت متن (ضد بریدگی/کاراکتر نامرئی) + بازنویسی تگ‌های
  // تصویر داخلی به لینک مطلق تصویرساز همین سرور.
  const content = sanitizeDariText(result.text)
    .replace(/ai-image:\/\/([^)\s]+)/g, (_m, desc: string) =>
      `${origin}/api/v1/ai-images/${encodeURIComponent(String(desc))}.png`,
    );

  await env.DB.prepare("UPDATE lessons SET content_body = ?, updated_at = datetime('now') WHERE id = ?")
    .bind(content, lesson.id)
    .run();

  return { status: 'ready', content };
}
