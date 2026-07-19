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

/**
 * یک کار خانگی متناسب با درسی که شاگرد همین الان باز کرده می‌سازد و در
 * `student_homeworks` ثبت می‌کند. اگر قبلاً برای همین جفتِ (شاگرد، درس) یک
 * کار خانگی ساخته شده باشد، دوباره نمی‌سازد (idempotent — هم‌سو با
 * `student_lesson_views` که خودش هم فقط یک‌بار برای هر درس فعال می‌شود).
 */
export async function autoAssignLessonHomework(env: LessonHomeworkEnv, p: LessonHomeworkParams): Promise<void> {
  if (!env.GEMINI_API_KEY) return; // سرویس هنوز پیکربندی نشده — بی‌صدا نادیده گرفته می‌شود.

  try {
    const existing = await env.DB.prepare(
      'SELECT id FROM student_homeworks WHERE student_id = ? AND lesson_id = ? LIMIT 1',
    )
      .bind(p.studentId, p.lessonId)
      .first();
    if (existing) return;

    // نکته (رفع باگ واقعی — نه فقط لاگ‌گذاری): مدل قدیمی «gemini-1.5-flash» از
    // طرف گوگل به‌طور کامل خاموش شده (هر درخواستی ۴۰۴ برمی‌گرداند) — دقیقاً
    // همان دلیلی که کار خانگی هرگز ساخته نمی‌شد. «gemini-3.5-flash» مدل پایدار
    // فعلی است (بدون تاریخ خاموشی اعلام‌شده، طبق ai.google.dev/gemini-api/docs/models).
    const model = env.GEMINI_VISION_MODEL ?? 'gemini-3.5-flash';
    const prompt =
      `شما یک معلم مهربان و باتجربهٔ افغان هستید. شاگردی صنف ${p.classLevel} همین الان درس زیر را از مضمون ` +
      `«${p.subjectNameFa}» مطالعه کرد:\n` +
      `عنوان درس: ${p.lessonTitleFa}\n` +
      `متن درس: ${p.lessonContentBody || '(متن کامل درس هنوز ثبت نشده — فقط بر اساس عنوان یک سؤال مناسب صنف بساز)'}\n\n` +
      `بر اساس دقیقاً همین درس، یک «کار خانگی» طراحی کن که شاگرد آن را با قلم روی کاغذ حل کند (سؤال تشریحی/محاسبه‌ای/` +
      `نوشتاری متناسب با موضوع درس — نه چهارگزینه‌ای). یک راهنمای کوتاه (یک جمله) هم برای شروع حل بنویس.\n\n` +
      `فقط یک شیء JSON خام با دقیقاً همین کلیدها برگردان، بدون هیچ توضیح اضافه:\n` +
      `{"questionText": "...", "hintText": "..."}`;

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
            temperature: 0.4,
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
      return;
    }
    const data = (await res.json()) as any;
    const text = data?.candidates?.[0]?.content?.parts?.map((part: any) => part.text ?? '').join('') ?? '';
    const parsed = extractJsonBlock(text);
    const questionText = String(parsed?.questionText ?? '').trim();
    if (!questionText) {
      console.error(`[lessonHomework] پاسخ Gemini قابل‌تجزیه به questionText نبود — متن خام: ${text.slice(0, 500)}`);
      return;
    }
    const hintText = String(parsed?.hintText ?? '').trim();

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
    );
  } catch (err) {
    console.error('[lessonHomework] auto-generate failed —', err);
  }
}
