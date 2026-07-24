/**
 * routes/homework.ts — «مشق کاغذی + نمره‌دهی هوشمند» (AI Paper-Based Homework
 * & Smart Grading). زیر `/api/v1` mount می‌شود.
 *
 * جریان کار:
 *   ۱) مدیر/معلم هوشمند یک مشق برای شاگرد ثبت می‌کند (status='pending').
 *   ۲) شاگرد روی کاغذ حل می‌کند، عکس می‌گیرد و آپلود می‌کند
 *      (`POST /homework/:id/submit`) → عکس روی R2، سپس Gemini Vision متن
 *      دست‌خط را می‌خواند (OCR) و از ۱۰۰ نمره می‌دهد؛ نتیجه در D1 ذخیره و
 *      امتیاز فعالیت شاگرد (بخش گیمیفیکیشن مشترک — `lib/progress.ts`)
 *      به‌روز می‌شود.
 *   ۳) شاگرد می‌تواند دربارهٔ نمره/بازخورد سؤال بپرسد
 *      (`POST /homework/:id/reply`) — پاسخ با آگاهی از همان مشق تولید می‌شود.
 *
 * صنف‌محور و آینده‌نگر: فهرست مشق‌های شاگرد همیشه بر اساس `users.current_grade`
 * *فعلی* او فیلتر می‌شود (نه یک صنف ثابت)، پس با هر ارتقای واقعی صنف
 * (`promoteIfEligible`)، فهرست خودکار هماهنگ می‌ماند — بدون کد اضافه.
 *
 * پیکربندی (همه اختیاری؛ در نبودشان Endpoint به‌جای کرش، پیام «پیکربندی
 * نشده» با ۵۰۳ برمی‌گرداند — همان اصل Fail-safe بقیهٔ سرویس‌های AI/TTS):
 *   wrangler secret put GEMINI_API_KEY
 *   [vars] GEMINI_VISION_MODEL = "gemini-3.5-flash"   (پیش‌فرض همین است)
 * برای گفت‌وگوی پیگیری (`/reply`) از همان AI_PROVIDER_KEY/AI_PROVIDER_URL
 * مشترکِ «معلم هوشمند» (`routes/ai.ts`) استفاده می‌شود — پیکربندی دوباره لازم نیست.
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { awardPoints, POINTS_PER_HOMEWORK_GRADED } from '../lib/progress';
import { sendPushToUser } from '../lib/push';
import { logAudit, clientIp } from '../lib/audit';

type Bindings = {
  DB: D1Database;
  BUCKET: R2Bucket;
  JWT_SECRET: string;
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
  AI_PROVIDER_KEY?: string;
  AI_PROVIDER_URL?: string;
  AI_MODEL?: string;
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
};

const homework = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function me(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

// ─────────────────────────────── JSON shaping ───────────────────────────────

function homeworkJson(r: any) {
  return {
    id: r.id,
    studentId: r.student_id,
    subjectId: r.subject_id,
    subjectNameFa: r.subject_name_fa ?? '',
    chapterId: r.chapter_id ?? '',
    lessonId: r.lesson_id ?? '',
    classLevel: r.class_level,
    questionText: r.question_text ?? '',
    hintText: r.hint_text ?? '',
    status: r.status,
    studentImageUrl: r.student_image_url ? `/files/${r.student_image_url}` : '',
    extractedText: r.extracted_text ?? '',
    aiScore: r.ai_score ?? null,
    aiFeedback: r.ai_feedback ?? '',
    createdAt: r.created_at,
    submittedAt: r.submitted_at ?? null,
    gradedAt: r.graded_at ?? null,
  };
}

function replyJson(r: any) {
  return {
    id: r.id,
    homeworkId: r.homework_id,
    sender: r.sender,
    text: r.message_text ?? '',
    createdAt: r.created_at,
  };
}

/** مالکیت واقعی — فقط خودِ شاگرد یا مدیر ارشد اجازه دارند (ضد IDOR، هماهنگ با seminars.ts). */
async function loadOwnedHomework(
  c: any,
  id: string,
  actor: { sub: string; role: string },
): Promise<{ ok: true; row: any } | { ok: false; response: Response }> {
  const row = await c.env.DB.prepare('SELECT * FROM student_homeworks WHERE id = ?').bind(id).first();
  if (!row) {
    return {
      ok: false,
      response: c.json(fail('NOT_FOUND', 'مشق یافت نشد', 'Homework not found', 'کورس ونه موندل شو', 'Devoir introuvable'), 404),
    };
  }
  if (actor.role !== 'super_admin' && row.student_id !== actor.sub) {
    return {
      ok: false,
      response: c.json(fail('FORBIDDEN', 'این مشق متعلق به شما نیست', 'Not your homework', 'دا کور ستاسو نه دی', 'Ce devoir ne vous appartient pas'), 403),
    };
  }
  return { ok: true, row };
}

// ───────────────────────────────── فهرست ────────────────────────────────────
// طبق صنف *فعلی* شاگرد (users.current_grade) — نه یک مقدار ثابت — تا با هر
// ارتقای صنف خودکار هماهنگ بماند. مدیر می‌تواند با ?studentId= مشق‌های هر
// شاگردی را ببیند.
//
// رفع اشکال «کار خانگی والد همیشه خالی است»: قبلاً `?studentId=` فقط برای
// `super_admin` معتبر بود؛ برای هر نقش دیگر (از جمله والد) بی‌صدا نادیده
// گرفته می‌شد و `studentId` به `actor.sub` (خودِ والد که هیچ کار خانگی‌ای
// ندارد) برمی‌گشت — یعنی صفحهٔ «کار خانگی» والد همیشه خالی بود، حتی وقتی
// فرزندش کار خانگی واقعی داشت. اکنون والد هم می‌تواند (فقط برای فرزند
// تأییدشدهٔ خودش، طبق `parent_student_links`) با همان پارامتر کار خانگی
// فرزندش را ببیند — دقیقاً همان نمایی که خودِ شاگرد می‌بیند (صنف فعلی، نه
// تاریخچهٔ کامل مثل نمای مدیر).
homework.get('/homework', async (c) => {
  const actor = await me(c);
  if (!actor) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);

  const requested = c.req.query('studentId');
  let studentId = actor.sub;
  let isAdminViewingOther = false;
  if (requested) {
    if (actor.role === 'super_admin') {
      studentId = requested;
      isAdminViewingOther = true;
    } else if (actor.role === 'parent') {
      const link = await c.env.DB.prepare(
        "SELECT 1 FROM parent_student_links WHERE parent_user_id = ? AND student_user_id = ? AND status = 'approved'",
      )
        .bind(actor.sub, requested)
        .first();
      if (link) studentId = requested;
      // اگر لینک تأییدشده نبود، بی‌صدا به `actor.sub` سقوط می‌کند (فهرست خالی)
      // نه خطا — تا هیچ اطلاعاتی دربارهٔ وجود/عدم‌وجود شاگرد فاش نشود.
    }
    // برای نقش شاگرد یا هر نقش دیگر، `studentId` عمداً همان `actor.sub`
    // باقی می‌ماند (محافظت در برابر IDOR).
  }
  const statusFilter = c.req.query('status'); // pending|submitted|graded

  const student = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?')
    .bind(studentId)
    .first<{ current_grade: number | null }>();
  const classLevel = student?.current_grade ?? 7;

  // شاگرد خودش: فقط فهرست صنف *فعلی* (تا با ارتقای صنف خودکار هماهنگ بماند
  // — منطق آینده‌نگر همان‌طور که در بقیهٔ این Endpoint هست). نمای مدیر روی
  // پروندهٔ یک شاگرد مشخص: کل تاریخچه (همهٔ صنف‌های گذشته هم)، چون مدیر باید
  // تصویر کامل فعالیت شاگرد را ببیند، نه فقط صنف فعلی‌اش.
  const clauses = ['h.student_id = ?'];
  const binds: any[] = [studentId];
  if (!isAdminViewingOther) {
    clauses.push('h.class_level = ?');
    binds.push(classLevel);
  }
  if (statusFilter && ['pending', 'submitted', 'graded'].includes(statusFilter)) {
    clauses.push('h.status = ?');
    binds.push(statusFilter);
  }

  const { results } = await c.env.DB.prepare(
    `SELECT h.*, s.name_fa AS subject_name_fa
       FROM student_homeworks h
       LEFT JOIN subjects s ON s.id = h.subject_id
      WHERE ${clauses.join(' AND ')}
      ORDER BY h.created_at DESC`,
  )
    .bind(...binds)
    .all<any>();

  // میانگین نمره — فقط از مشق‌های نمره‌داده‌شده (برای هدر داشبورد).
  const gradedScores = results.filter((r) => r.ai_score != null).map((r) => r.ai_score as number);
  const averageScore =
    gradedScores.length > 0 ? Math.round((gradedScores.reduce((a, b) => a + b, 0) / gradedScores.length) * 10) / 10 : null;

  return c.json({
    classLevel,
    averageScore,
    homeworks: results.map(homeworkJson),
  });
});

homework.get('/homework/:id', async (c) => {
  const actor = await me(c);
  if (!actor) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const owned = await loadOwnedHomework(c, c.req.param('id'), actor);
  if (!owned.ok) return owned.response;
  const row = await c.env.DB.prepare('SELECT h.*, s.name_fa AS subject_name_fa FROM student_homeworks h LEFT JOIN subjects s ON s.id = h.subject_id WHERE h.id = ?')
    .bind(owned.row.id)
    .first<any>();
  const { results: replies } = await c.env.DB.prepare(
    'SELECT * FROM homework_replies WHERE homework_id = ? ORDER BY created_at ASC',
  )
    .bind(owned.row.id)
    .all<any>();
  return c.json({ homework: homeworkJson(row), replies: replies.map(replyJson) });
});

// ─────────────────────── ثبت مشق جدید (مدیر/معلم هوشمند) ────────────────────
// معمولاً از پنل مدیریت یا خودکار توسط معلم هوشمند صدا زده می‌شود.

homework.post('/homework', async (c) => {
  const actor = await me(c);
  if (!actor || actor.role !== 'super_admin') {
    return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  }
  const b = await c.req.json<Record<string, any>>().catch(() => null);
  if (!b?.studentId || !b?.subjectId || !b?.questionText) {
    return c.json(fail('BAD_REQUEST', 'شاگرد، مضمون و متن سؤال الزامی است', 'studentId, subjectId and questionText are required'), 400);
  }
  const student = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?')
    .bind(String(b.studentId))
    .first<{ current_grade: number | null }>();
  const classLevel = Number(b.classLevel ?? student?.current_grade ?? 7);
  const id = `hw_${uid()}`;
  await c.env.DB.prepare(
    `INSERT INTO student_homeworks
       (id, student_id, subject_id, chapter_id, lesson_id, class_level, question_text, hint_text, status)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
  )
    .bind(
      id,
      String(b.studentId),
      String(b.subjectId),
      String(b.chapterId ?? ''),
      String(b.lessonId ?? ''),
      classLevel,
      String(b.questionText),
      String(b.hintText ?? ''),
    )
    .run();
  await c.env.DB.prepare(
    "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind, related_id) VALUES (?, ?, ?, ?, 'medium', 'homework', ?)",
  )
    .bind(uid(), String(b.studentId), 'کار خانگی جدید 📝', 'یک کار خانگی تازه برای شما ثبت شد — از بخش «کار خانگی» عکس حل‌تان را بفرستید.', id)
    .run()
    .catch(() => {}); // جدول اعلان ممکن است در برخی محیط‌ها هنوز نداشته باشد — بی‌اثر نادیده گرفته می‌شود.
  // Push واقعی روی گوشی (در نبود پیکربندی FCM، بی‌صدا نادیده گرفته می‌شود).
  c.executionCtx.waitUntil(
    sendPushToUser(
      c.env,
      String(b.studentId),
      'کار خانگی جدید 📝',
      'یک کار خانگی تازه برای شما ثبت شد — از بخش «کار خانگی» عکس حل‌تان را بفرستید.',
      { kind: 'homework', relatedId: id },
    ),
  );
  const row = await c.env.DB.prepare('SELECT * FROM student_homeworks WHERE id = ?').bind(id).first<any>();
  return c.json({ homework: homeworkJson(row) }, 201);
});

// ───────────────────── ارسال عکس + نمره‌دهی هوشمند (Vision) ─────────────────
// بدنه: multipart/form-data با فیلد `file` (عکس دست‌خط شاگرد — jpeg/png).

const MAX_IMAGE_BYTES = 12 * 1024 * 1024; // ۱۲ مگابایت

function bytesToBase64(bytes: Uint8Array): string {
  let binary = '';
  const chunkSize = 0x8000; // جلوگیری از سرریز آرگومان در فایل‌های بزرگ
  for (let i = 0; i < bytes.length; i += chunkSize) {
    binary += String.fromCharCode(...bytes.subarray(i, i + chunkSize));
  }
  return btoa(binary);
}

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

async function gradeWithGemini(
  apiKey: string,
  model: string,
  imageBase64: string,
  mimeType: string,
  questionText: string,
): Promise<{ extractedText: string; score: number; feedbackFa: string } | null> {
  // نمره‌دهی عمداً «سخت‌گیر نیست» — طبق درخواست صریح: شاگردان دختر تازه‌کار
  // نباید با یک نمرهٔ بسیار پایین ناامید شوند و از ادامهٔ درس دلسرد شوند.
  // این تنها روی خودِ عدد/بازخورد اثر می‌گذارد (نه بر باز/قفل بودن درس بعدی —
  // آن مستقل و بدون آستانهٔ نمره در lib/progress.ts تصمیم‌گیری می‌شود).
  const prompt =
    `شما یک معلم مهربان و دلگرم‌کنندهٔ افغان هستید که به شاگردان دختر (اغلب تازه‌کار) درس می‌دهید. ` +
    `تصویر زیر دست‌خط یک شاگرد است که به این سؤال پاسخ داده: «${questionText}». وظیفهٔ شما:\n` +
    `۱) متن دست‌نویس را از روی عکس دقیقاً بخوانید (OCR) — اگر به دری/پشتو نوشته شده همان‌طور بنویسید.\n` +
    `۲) پاسخ را از ۰ تا ۱۰۰ نمره بدهید — اما **سخت‌گیر نباشید**: برای مراحل درست/تلاش واقعی حتی اگر جواب نهایی کامل نیست نمرهٔ نسبی (partial credit) بدهید؛ روی خوانایی خط یا اشتباهات املایی جزئی سخت‌گیری نکنید مگر واقعاً غیرقابل‌خواندن باشد؛ یک تلاش جدی و مرتبط با سؤال معمولاً باید حداقل نمرهٔ متوسط (حدود ۵۰ تا ۶۰) بگیرد، نه صفر یا نمرهٔ خیلی پایین. نمرهٔ خیلی پایین (زیر ۳۰) را فقط برای برگهٔ خالی یا پاسخ کاملاً بی‌ربط بگذارید.\n` +
    `۳) یک بازخورد کوتاه، بسیار مهربان، تشویق‌کننده و سازنده به زبان دری بنویسید (۲ تا ۴ جمله) — همیشه اول یک نقطهٔ قوت واقعی را بگویید، بعد با لحن دلگرم‌کننده (نه سرزنش‌آمیز) بگویید چه چیزی را می‌تواند بهتر کند.\n\n` +
    `فقط یک شیء JSON خام با دقیقاً همین کلیدها برگردانید، بدون هیچ توضیح اضافه:\n` +
    `{"extractedText": "...", "score": 0, "feedbackFa": "..."}`;

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: prompt }, { inline_data: { mime_type: mimeType, data: imageBase64 } }],
          },
        ],
        // نکته (رفع باگ واقعی هم‌سو با lib/lessonHomework.ts): gemini-3.5-flash
        // به‌طور پیش‌فرض «تفکر» (thinking) با سطح medium روشن دارد و توکن‌های
        // آن از همان سقف maxOutputTokens کم می‌شوند — برای وظیفهٔ OCR/نمره‌دهی
        // که پیچیدگی استدلالی بالایی ندارد، thinkingLevel را minimal می‌کنیم
        // تا کل بودجه برای متن واقعی پاسخ (JSON) باقی بماند.
        generationConfig: {
          temperature: 0.2,
          maxOutputTokens: 1024,
          thinkingConfig: { thinkingLevel: 'minimal' },
        },
      }),
    },
  );
  if (!res.ok) {
    // رفع اشکال مشاهده‌پذیری (هم‌سو با lib/lessonHomework.ts): قبلاً این خط
    // بی‌صدا null برمی‌گرداند — یعنی اگر مدل منسوخ/غیرفعال می‌شد، هیچ ردی در
    // لاگ دیده نمی‌شد. حالا خطای واقعی HTTP ثبت می‌شود (هنوز fail-safe کامل).
    const errBody = await res.text().catch(() => '');
    console.error(`[homework] Gemini HTTP ${res.status} — ${errBody.slice(0, 500)}`);
    return null;
  }
  const data = (await res.json()) as any;
  const text = data?.candidates?.[0]?.content?.parts?.map((p: any) => p.text ?? '').join('') ?? '';
  const parsed = extractJsonBlock(text);
  if (!parsed) {
    console.error(`[homework] پاسخ Gemini قابل‌تجزیه نبود — متن خام: ${text.slice(0, 500)}`);
    return null;
  }
  const score = Math.max(0, Math.min(100, Math.round(Number(parsed.score ?? 0))));
  return {
    extractedText: String(parsed.extractedText ?? '').trim(),
    score,
    feedbackFa: String(parsed.feedbackFa ?? '').trim(),
  };
}

homework.post('/homework/:id/submit', async (c) => {
  const actor = await me(c);
  if (!actor) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const owned = await loadOwnedHomework(c, c.req.param('id'), actor);
  if (!owned.ok) return owned.response;
  const hw = owned.row;

  const form = await c.req.formData().catch(() => null);
  const file = form?.get('file') as File | null;
  if (!file) {
    return c.json(fail('BAD_REQUEST', 'عکس مشق الزامی است', 'An image file is required', 'د کور انځور اړین دی', 'Une image du devoir est requise'), 400);
  }
  const bytes = new Uint8Array(await file.arrayBuffer());
  if (bytes.length === 0 || bytes.length > MAX_IMAGE_BYTES) {
    return c.json(
      fail('BAD_SIZE', 'حجم عکس باید بین ۱ بایت و ۱۲ مگابایت باشد', 'Image size must be between 1 byte and 12MB'),
      400,
    );
  }
  const mimeType = file.type && file.type.startsWith('image/') ? file.type : 'image/jpeg';
  const ext = mimeType.includes('png') ? 'png' : 'jpg';

  // ۱) آپلود روی R2 — همیشه اول ذخیره می‌شود، حتی اگر نمره‌دهی بعداً ناموفق شود
  //    (اصل Fail-safe: شاگرد هرگز کارش را از دست نمی‌دهد).
  const imageKey = `homework/${hw.student_id}/${hw.id}_${Date.now()}.${ext}`;
  await c.env.BUCKET.put(imageKey, bytes, { httpMetadata: { contentType: mimeType } });
  await c.env.DB.prepare(
    "UPDATE student_homeworks SET student_image_url = ?, status = 'submitted', submitted_at = datetime('now') WHERE id = ?",
  )
    .bind(imageKey, hw.id)
    .run();

  // ۲) نمره‌دهی هوشمند (Gemini Vision) — اختیاری: اگر پیکربندی نشده یا خطا
  //    داد، مشق همچنان با status='submitted' باقی می‌ماند (بعداً می‌توان
  //    دوباره تلاش کرد)؛ هرگز کل درخواست را با خطا رد نمی‌کنیم.
  if (!c.env.GEMINI_API_KEY) {
    const row = await c.env.DB.prepare('SELECT h.*, s.name_fa AS subject_name_fa FROM student_homeworks h LEFT JOIN subjects s ON s.id = h.subject_id WHERE h.id = ?')
      .bind(hw.id)
      .first<any>();
    return c.json({
      homework: homeworkJson(row),
      graded: false,
      notice: 'سرویس نمره‌دهی هوشمند هنوز روی سرور پیکربندی نشده — عکس شما ذخیره شد و بعداً نمره داده می‌شود.',
    });
  }

  try {
    const base64 = bytesToBase64(bytes);
    // رفع باگ واقعی: gemini-1.5-flash از طرف گوگل کاملاً خاموش شده (۴۰۴ برای
    // هر درخواست) — همان دلیلی که نمره‌دهی عکس هرگز کار نمی‌کرد.
    // gemini-3.5-flash مدل پایدار فعلی و چندرسانه‌ای (متن+عکس) است.
    const model = c.env.GEMINI_VISION_MODEL ?? 'gemini-3.5-flash';
    const graded = await gradeWithGemini(c.env.GEMINI_API_KEY, model, base64, mimeType, hw.question_text ?? '');
    // Auditability (بخش ۵.۶/۲۰.۳ سند): این هم یک فراخوانی AI با دادهٔ شاگرد
    // است (عکس دست‌خط + سؤال مشق) — دقیقاً هم‌خانوادهٔ 'ai_invocation' که
    // «مرکز عملیات و لاگ بازبینی» از قبل برایش نمای اختصاصی (Prompt/RAG)
    // دارد؛ قبلاً هیچ ردی از نمره‌دهی هوشمند در آن صفحه دیده نمی‌شد.
    const auditPrompt = [
      { role: 'system', content: `سؤال مشق: ${hw.question_text ?? ''}` },
      { role: 'user', content: '[تصویر دست‌خط شاگرد — محتوای باینری در لاگ ذخیره نمی‌شود]' },
    ];
    if (!graded) {
      c.executionCtx.waitUntil(
        logAudit(c.env.DB, {
          actorId: actor.sub,
          actorRole: actor.role,
          actionType: 'ai_invocation',
          targetTable: 'student_homeworks',
          targetId: hw.id,
          ipAddress: clientIp(c),
          detail: { subjectId: hw.subject_id, model, outcome: 'upstream_error', prompt: auditPrompt },
        }),
      );
      const row = await c.env.DB.prepare('SELECT h.*, s.name_fa AS subject_name_fa FROM student_homeworks h LEFT JOIN subjects s ON s.id = h.subject_id WHERE h.id = ?')
        .bind(hw.id)
        .first<any>();
      return c.json({ homework: homeworkJson(row), graded: false, notice: 'نمره‌دهی هوشمند موقتاً ناموفق بود؛ عکس شما ذخیره شد.' });
    }
    await c.env.DB.prepare(
      "UPDATE student_homeworks SET extracted_text = ?, ai_score = ?, ai_feedback = ?, status = 'graded', graded_at = datetime('now') WHERE id = ?",
    )
      .bind(graded.extractedText, graded.score, graded.feedbackFa, hw.id)
      .run();
    c.executionCtx.waitUntil(
      logAudit(c.env.DB, {
        actorId: actor.sub,
        actorRole: actor.role,
        actionType: 'ai_invocation',
        targetTable: 'student_homeworks',
        targetId: hw.id,
        ipAddress: clientIp(c),
        detail: {
          subjectId: hw.subject_id,
          model,
          outcome: 'ok',
          prompt: auditPrompt,
          replyPreview: `نمره: ${graded.score}/100 — ${graded.feedbackFa}`.slice(0, 400),
        },
      }),
    );

    // امتیاز فعالیت (بخش گیمیفیکیشن مشترک) — هر مشق فقط یک‌بار امتیاز می‌دهد
    // چون status از 'graded' به 'graded' دوباره نمی‌رود مگر با submit تازه.
    await awardPoints(c.env.DB, hw.student_id, POINTS_PER_HOMEWORK_GRADED, 'homework_graded', hw.id).catch(() => {});

    const row = await c.env.DB.prepare('SELECT h.*, s.name_fa AS subject_name_fa FROM student_homeworks h LEFT JOIN subjects s ON s.id = h.subject_id WHERE h.id = ?')
      .bind(hw.id)
      .first<any>();
    return c.json({ homework: homeworkJson(row), graded: true });
  } catch (err) {
    console.error('[homework/submit] grading failed —', err);
    const row = await c.env.DB.prepare('SELECT h.*, s.name_fa AS subject_name_fa FROM student_homeworks h LEFT JOIN subjects s ON s.id = h.subject_id WHERE h.id = ?')
      .bind(hw.id)
      .first<any>();
    return c.json({ homework: homeworkJson(row), graded: false, notice: 'نمره‌دهی هوشمند موقتاً ناموفق بود؛ عکس شما ذخیره شد.' });
  }
});

// ─────────────────── گفت‌وگوی پیگیری دربارهٔ نمره (Reply) ───────────────────
// شاگرد می‌تواند دربارهٔ بازخورد/نمرهٔ همین مشق سؤال بپرسد؛ پاسخ با آگاهی از
// متن سؤال + دست‌خط استخراج‌شده + بازخورد قبلی تولید می‌شود (بدون RAG جداگانه
// — بخش سبک همین Endpoint).

homework.get('/homework/:id/replies', async (c) => {
  const actor = await me(c);
  if (!actor) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const owned = await loadOwnedHomework(c, c.req.param('id'), actor);
  if (!owned.ok) return owned.response;
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM homework_replies WHERE homework_id = ? ORDER BY created_at ASC',
  )
    .bind(owned.row.id)
    .all<any>();
  return c.json({ replies: results.map(replyJson) });
});

homework.post('/homework/:id/reply', async (c) => {
  const actor = await me(c);
  if (!actor) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const owned = await loadOwnedHomework(c, c.req.param('id'), actor);
  if (!owned.ok) return owned.response;
  const hw = owned.row;

  const b = await c.req.json<{ text?: string }>().catch(() => null);
  const studentText = (b?.text ?? '').trim();
  if (!studentText) {
    return c.json(fail('BAD_REQUEST', 'متن پیام نمی‌تواند خالی باشد', 'Message text cannot be empty'), 400);
  }
  if (hw.status !== 'graded') {
    return c.json(
      fail('NOT_GRADED_YET', 'هنوز نمرهٔ این مشق آماده نشده — بعد از نمره‌دهی می‌توانید سؤال بپرسید', 'This homework has not been graded yet'),
      400,
    );
  }

  // ذخیرهٔ پیام شاگرد.
  await c.env.DB.prepare(
    "INSERT INTO homework_replies (id, homework_id, sender, message_text) VALUES (?, ?, 'student', ?)",
  )
    .bind(`hwr_${uid()}`, hw.id, studentText)
    .run();

  // تاریخچهٔ کوتاه گفت‌وگو (تا ۱۰ پیام قبلی) برای Context.
  const { results: history } = await c.env.DB.prepare(
    'SELECT sender, message_text FROM homework_replies WHERE homework_id = ? ORDER BY created_at ASC LIMIT 20',
  )
    .bind(hw.id)
    .all<{ sender: string; message_text: string }>();

  let aiText: string;
  // خارج از try/catch تعریف شده تا هم مسیر موفق و هم مسیر خطا (Auditability
  // بخش ۵.۶/۲۰.۳) بتوانند همین Prompt کامل را در audit_logs ثبت کنند.
  const systemPrompt =
    `شما معلم هوشمند مکتب دیجیتال دختران افغانستان هستید — مهربان، صبور و دقیق. ` +
    `دربارهٔ همین مشق مشخص با شاگرد گفت‌وگو می‌کنید:\n` +
    `سؤال مشق: ${hw.question_text}\n` +
    `متن دست‌نویس استخراج‌شده: ${hw.extracted_text || '(ثبت نشده)'}\n` +
    `نمرهٔ داده‌شده: ${hw.ai_score ?? 'نامشخص'} از ۱۰۰\n` +
    `بازخورد قبلی: ${hw.ai_feedback || '(ثبت نشده)'}\n` +
    `فقط به زبان دری، کوتاه و تشویق‌کننده پاسخ بده — دقیقاً به همان چیزی که شاگرد می‌پرسد.`;
  const messages = [
    { role: 'system', content: systemPrompt },
    ...history.map((h) => ({ role: h.sender === 'student' ? 'user' : 'assistant', content: h.message_text })),
  ];
  if (!c.env.AI_PROVIDER_KEY) {
    // Fail-safe محلی — بدون موتور ابری هم شاگرد جواب خالی نمی‌بیند.
    aiText =
      hw.ai_score != null
        ? `نمرهٔ شما ${hw.ai_score} از ۱۰۰ بود. بازخورد قبلی: ${hw.ai_feedback || 'در دسترس نیست'}. برای راهنمایی بیشتر، لطفاً دوباره از معلم هوشمند در بخش «معلم هوشمند» بپرسید.`
        : 'این مشق هنوز نمره نگرفته است.';
  } else {
    try {
      const res = await fetch(c.env.AI_PROVIDER_URL ?? 'https://api.openai.com/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${c.env.AI_PROVIDER_KEY}`,
        },
        body: JSON.stringify({
          model: c.env.AI_MODEL ?? 'gpt-4o-mini',
          messages,
          temperature: 0.5,
          max_tokens: 400,
        }),
      });
      if (!res.ok) throw new Error(`upstream ${res.status}`);
      const data = (await res.json()) as any;
      aiText = data?.choices?.[0]?.message?.content?.trim() || 'متأسفم، در حال حاضر نمی‌توانم پاسخ بدهم — دوباره تلاش کنید.';
      c.executionCtx.waitUntil(
        logAudit(c.env.DB, {
          actorId: actor.sub,
          actorRole: actor.role,
          actionType: 'ai_invocation',
          targetTable: 'homework_replies',
          targetId: hw.id,
          ipAddress: clientIp(c),
          detail: {
            subjectId: hw.subject_id,
            model: c.env.AI_MODEL ?? 'gpt-4o-mini',
            outcome: 'ok',
            prompt: messages,
            replyPreview: aiText.slice(0, 400),
          },
        }),
      );
    } catch (err) {
      console.error('[homework/reply] AI failed —', err);
      aiText = 'اتصال به معلم هوشمند موقتاً ناموفق بود؛ لطفاً کمی بعد دوباره تلاش کنید.';
      c.executionCtx.waitUntil(
        logAudit(c.env.DB, {
          actorId: actor.sub,
          actorRole: actor.role,
          actionType: 'ai_invocation',
          targetTable: 'homework_replies',
          targetId: hw.id,
          ipAddress: clientIp(c),
          detail: { subjectId: hw.subject_id, model: c.env.AI_MODEL ?? 'gpt-4o-mini', outcome: 'upstream_error', prompt: messages },
        }),
      );
    }
  }

  await c.env.DB.prepare(
    "INSERT INTO homework_replies (id, homework_id, sender, message_text) VALUES (?, ?, 'ai', ?)",
  )
    .bind(`hwr_${uid()}`, hw.id, aiText)
    .run();

  const { results: replies } = await c.env.DB.prepare(
    'SELECT * FROM homework_replies WHERE homework_id = ? ORDER BY created_at ASC',
  )
    .bind(hw.id)
    .all<any>();
  return c.json({ replies: replies.map(replyJson) });
});

export default homework;
