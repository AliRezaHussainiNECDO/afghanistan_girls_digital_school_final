/**
 * lib/lessonHomework.ts — تولید خودکار «کار خانگی» از روی محتوای واقعی درس.
 *
 * منطق (اتصال «کار خانگی» به نصاب درسی): وقتی شاگرد برای *اولین بار* یک درس
 * را باز می‌کند (`POST /lessons/:lessonId/view` در routes/curriculum.ts —
 * دقیقاً همان لحظه‌ای که `recordLessonView` مقدار `firstView=true` برمی‌گرداند)،
 * همین تابع در پس‌زمینه (`c.executionCtx.waitUntil`) صدا زده می‌شود تا Gemini
 * بر اساس متن واقعی همان درس (`lessons.content_body`) یک سؤال کار خانگیِ
 * متناسب با همان مضمون/صنف بسازد و در `student_homeworks` ثبت کند — دقیقاً
 * همان جدولی که بخش «کار خانگی» (`routes/homework.ts`) از آن می‌خواند، پس
 * بدون هیچ تغییر دیگری، هم اکنون در داشبورد شاگرد ظاهر می‌شود.
 *
 * کاملاً عمومی و صنف/مضمون‌محور نیست — چون فقط از متن واقعی درس (که خودش
 * برای هر مضمون/صنفی در `lessons.content_body` ذخیره شده) استفاده می‌کند،
 * بدون هیچ prompt یا شرط مخصوص یک مضمون خاص، برای تمام ۱۰ مضمون و تمام
 * صنف‌های ۷ تا ۱۲ یکسان کار می‌کند.
 *
 * Fail-safe کامل: نبود GEMINI_API_KEY، خطای شبکه، یا پاسخ نامعتبر مدل —
 * هیچ‌کدام باعث خطا در `POST /lessons/:lessonId/view` نمی‌شوند (چون این تابع
 * از قبل با `waitUntil` جدا از پاسخ اصلی اجرا می‌شود)؛ فقط با console.error
 * ثبت و بی‌صدا نادیده گرفته می‌شوند.
 */

import { sendPushToUser } from './push';
import { DARI_OUTPUT_RULES, sanitizeDariText } from './gemini';

type LessonHomeworkEnv = {
  DB: D1Database;
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
};

type LessonHomeworkParams = {
  studentId: string;
  lessonId: string;
  chapterId: string;
  subjectId: string;
  subjectNameFa: string;
  classLevel: number;
  lessonTitleFa: string;
  lessonContentBody: string;
};

/** استخراج اولین بلوک JSON معتبر از متن — مدل گاهی آن را داخل ```json می‌گذارد. */
function extractJsonBlock(text: string): any | null {
  const fencedMatch = text.match(/```(?:json)?\s*([\s\S]*?)```/i);
  const candidate = fencedMatch ? fencedMatch[1] : text;
  const start = candidate.indexOf('{');
  const end = candidate.lastIndexOf('}');
  if (start === -1 || end === -1 || end < start) return null;
  try {
    return JSON.parse(candidate.slice(start, end + 1));
  } catch {
    return null;
  }
}

/// نتیجهٔ تلاش برای ساخت کار خانگی — به کلاینت برمی‌گردد تا پیام درست نشان
/// دهد (رفع اشکال: قبلاً void بود و صدازننده هیچ اطلاعی از نتیجه نداشت).
/// `rate_limited` = سهمیهٔ رایگان Gemini (Free Tier) موقتاً تمام شده —
/// فلاتر آن را با SnackBar محترمانه نشان می‌دهد و شاگرد بعداً دوباره می‌زند.
export type HomeworkAssignOutcome = 'created' | 'exists' | 'failed' | 'not_configured' | 'rate_limited';

/**
 * یک کار خانگی متناسب با درسی که شاگرد اعلام کرده «یاد گرفتم» می‌سازد و در
 * `student_homeworks` ثبت می‌کند (صدازننده: `POST /lessons/:lessonId/learned`
 * در routes/curriculum.ts — دیگر با بازدید خودکارِ درس ساخته نمی‌شود، طبق
 * درخواست کاربر). اگر قبلاً برای همین جفتِ (شاگرد، درس) یک کار خانگی ساخته
 * شده باشد، دوباره نمی‌سازد (idempotent) — یعنی زدنِ دوبارهٔ «این درس را یاد
 * گرفتم» روی همان درس، کار خانگی تکراری نمی‌دهد؛ فقط درس‌های جدید کار خانگی
 * تازه می‌گیرند.
 */
export async function autoAssignLessonHomework(env: LessonHomeworkEnv, p: LessonHomeworkParams): Promise<HomeworkAssignOutcome> {
  try {
    // بررسی یکتایی قبل از بررسی کلید — تا حتی بدون GEMINI_API_KEY هم پیام
    // «قبلاً داده شده» دقیق باشد.
    const existing = await env.DB.prepare(
      'SELECT id FROM student_homeworks WHERE student_id = ? AND lesson_id = ? LIMIT 1',
    )
      .bind(p.studentId, p.lessonId)
      .first();
    if (existing) return 'exists';
    if (!env.GEMINI_API_KEY) return 'not_configured'; // سرویس هنوز پیکربندی نشده.

    // نکته (رفع باگ واقعی — نه فقط لاگ‌گذاری): مدل قدیمی «gemini-1.5-flash» از
    // طرف گوگل به‌طور کامل خاموش شده (هر درخواستی ۴۰۴ برمی‌گرداند) — دقیقاً
    // همان دلیلی که کار خانگی هرگز ساخته نمی‌شد. «gemini-3.5-flash» مدل پایدار
    // فعلی است (بدون تاریخ خاموشی اعلام‌شده، طبق ai.google.dev/gemini-api/docs/models).
    const model = env.GEMINI_VISION_MODEL ?? 'gemini-3.5-flash';
    // ── «دیوار امنیتی بتنی» دور پرامپت (رفع قطعی کار خانگی بی‌ربط به درس) ──
    // ۳ لایهٔ مهار: (۱) مرزبندی صریح متن درس با """ تا مدل بداند «کتاب» فقط
    // همین است؛ (۲) قفل منفی (Negative Constraints) با مثال‌های صریحِ ممنوع؛
    // (۳) خودآزمایی اجباری قبل از خروجی («اگر پاسخ در متن نیست، سوال را دور
    // بریز»). راهنمای حل (💡) هم صریحاً به همین متن محدود می‌شود — همان
    // نقطه‌ای که مدل قبلاً «به بخش شکل زمین و گودال ماریانا» ارجاع می‌داد.
    const hasContent = p.lessonContentBody.trim().length > 0;
    const prompt =
      `تو یک ناظر آموزشی سخت‌گیر معارف افغانستان هستی. شاگرد صنف ${p.classLevel} همین حالا درس ` +
      `«${p.lessonTitleFa}» را از مضمون «${p.subjectNameFa}» تمام کرده است.\n\n` +
      (hasContent
        ? `متن درس — تنها منبع مجاز تو؛ فرض کن بیرون از این متن هیچ کتاب و هیچ دانشی وجود ندارد:\n` +
          `"""\n${p.lessonContentBody}\n"""\n\n`
        : `(متن کامل درس هنوز ثبت نشده — فقط بر اساس عنوان درس یک سؤال سادهٔ مناسب صنف بساز و در راهنما فقط به عنوان درس اشاره کن.)\n\n`) +
      `از روی دقیقاً همین متن، یک «کار خانگی» طرح کن که شاگرد آن را با قلم روی کاغذ حل کند ` +
      `(سؤال تشریحی/محاسبه‌ای/نوشتاری — نه چهارگزینه‌ای) + یک راهنمای یک‌جمله‌ای برای شروع حل.\n\n` +
      `⚠️ قوانین بسیار سخت‌گیرانه و حیاتی (تخطی = خروجی مردود):\n` +
      `۱. سوال و راهنما باید ۱۰۰٪ و بدون استثنا فقط از اطلاعات صریحِ موجود بین """ بالا ساخته شوند.\n` +
      `۲. حق نداری دربارهٔ هیچ موضوعی که در متن بالا نیامده سوال بسازی یا در راهنما به آن اشاره کنی — ` +
      `حتی اگر در درس‌ها یا فصل‌های دیگر همین کتاب باشد، حتی اگر در دانش عمومی خودت باشد. ` +
      `(مثال‌های ممنوع اگر در متن نیامده باشند: شکل زمین، قطر قطبی و استوایی، گودال ماریانا، هر عدد یا نام خاصی خارج از متن.)\n` +
      `۳. خودآزمایی اجباری: قبل از خروجی، بررسی کن که پاسخ کامل سوال را بتوان مستقیماً از جملات متن بالا پیدا کرد؛ ` +
      `اگر نمی‌شود، آن سوال را دور بریز و سوال ساده‌تری از همان متن بساز.\n` +
      `۴. در راهنمای حل (hintText) فقط به بخش‌ها و جملات همین متن ارجاع بده.\n\n` +
      `فقط یک شیء JSON خام با دقیقاً همین کلیدها برگردان، بدون هیچ توضیح اضافه:\n` +
      `{"questionText": "...", "hintText": "..."}` +
      DARI_OUTPUT_RULES;

    const res = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${env.GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          // نکته (رفع باگ واقعی دوم): gemini-3.5-flash به‌طور پیش‌فرض «تفکر»
          // (thinking) را با سطح medium روشن دارد، و توکن‌های تفکر از همان
          // سقف maxOutputTokens کم می‌شوند. با سقف قدیمی ۵۰۰، کل بودجه صرف
          // تفکر پنهان می‌شد و چیزی برای پاسخ نهایی (JSON) باقی نمی‌ماند —
          // یعنی Gemini واقعاً جواب می‌داد ولی متن برگشتی خالی/ناقص بود، پس
          // extractJsonBlock شکست می‌خورد. این کار خانگی یک وظیفهٔ سادهٔ
          // تولید متن است، نه استدلال پیچیده — پس thinkingLevel را minimal
          // می‌کنیم و سقف را هم بالاتر می‌بریم تا با احتیاط بیشتر جا شود.
          generationConfig: {
            // دمای پایین = پایبندی حداکثری به متن درس (خلاقیت خارج از متن ممنوع).
            temperature: 0.2,
            maxOutputTokens: 1024,
            thinkingConfig: { thinkingLevel: 'minimal' },
          },
        }),
      },
    );
    if (!res.ok) {
      // رفع اشکال مشاهده‌پذیری: قبلاً این مسیر کاملاً بی‌صدا برمی‌گشت — یعنی اگر
      // مدل Gemini منسوخ/غیرفعال می‌شد یا کلید رد می‌شد، هیچ ردی در `wrangler
      // tail` دیده نمی‌شد و عیب‌یابی غیرممکن بود. حالا خطای واقعی ثبت می‌شود
      // (هنوز fail-safe کامل — این تابع همچنان چیزی throw نمی‌کند).
      const errBody = await res.text().catch(() => '');
      console.error(`[lessonHomework] Gemini HTTP ${res.status} — ${errBody.slice(0, 500)}`);
      // مدیریت صریح Rate Limit سهمیهٔ رایگان (429 / RESOURCE_EXHAUSTED):
      // سرور کرش نمی‌کند؛ نتیجهٔ خوانا به کلاینت برمی‌گردد تا SnackBar بومی
      // «قفل موقت سیستم» نشان داده شود.
      if (res.status === 429 || errBody.includes('RESOURCE_EXHAUSTED')) return 'rate_limited';
      return 'failed';
    }
    const data = (await res.json()) as any;
    const text = data?.candidates?.[0]?.content?.parts?.map((part: any) => part.text ?? '').join('') ?? '';
    const parsed = extractJsonBlock(text);
    const questionText = sanitizeDariText(String(parsed?.questionText ?? ''));
    if (!questionText) {
      console.error(`[lessonHomework] پاسخ Gemini قابل‌تجزیه به questionText نبود — متن خام: ${text.slice(0, 500)}`);
      return 'failed';
    }
    const hintText = sanitizeDariText(String(parsed?.hintText ?? ''));

    const id = `hw_${crypto.randomUUID()}`;
    await env.DB.prepare(
      `INSERT INTO student_homeworks
         (id, student_id, subject_id, chapter_id, lesson_id, class_level, question_text, hint_text, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
    )
      .bind(id, p.studentId, p.subjectId, p.chapterId, p.lessonId, p.classLevel, questionText, hintText)
      .run();

    await env.DB.prepare(
      "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind, related_id) VALUES (?, ?, ?, ?, 'medium', 'homework', ?)",
    )
      .bind(
        crypto.randomUUID(),
        p.studentId,
        'کار خانگی جدید 📝',
        `بر اساس درس «${p.lessonTitleFa}» یک کار خانگی تازه برایتان آماده شد — از بخش «کار خانگی» عکس حل‌تان را بفرستید.`,
        id,
      )
      .run()
      .catch(() => {});

    // Push واقعی روی گوشی — این تابع خودش از قبل با `waitUntil` در پس‌زمینه
    // اجرا می‌شود (curriculum.ts)، پس همین‌جا مستقیم await می‌کنیم.
    await sendPushToUser(
      env,
      p.studentId,
      'کار خانگی جدید 📝',
      `بر اساس درس «${p.lessonTitleFa}» یک کار خانگی تازه برایتان آماده شد — از بخش «کار خانگی» عکس حل‌تان را بفرستید.`,
      { kind: 'homework', relatedId: id },
    );
    return 'created';
  } catch (err) {
    console.error('[lessonHomework] auto-generate failed —', err);
    return 'failed';
  }
}
