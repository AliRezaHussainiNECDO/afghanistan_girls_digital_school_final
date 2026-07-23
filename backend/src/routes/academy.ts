/**
 * routes/academy.ts — «آکادمی»: کتابخانه، بانک سؤال و پاسخ‌ها روی سرور.
 * زیر `/api/v1` mount می‌شود.
 *
 * خواندن برای هر کاربر واردشده؛ نوشتن کتاب/سؤال فقط مدیر؛ ثبت پاسخ توسط شاگرد.
 * شناسهٔ رکوردها را کلاینت می‌فرستد (Upsert با INSERT OR REPLACE) تا کشِ محلی
 * و سرور همیشه هماهنگ بمانند.
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { logAudit, clientIp } from '../lib/audit';
import { gradeEssaysWithAi } from '../lib/essayGrading';

type Bindings = {
  DB: D1Database;
  BUCKET: R2Bucket;
  JWT_SECRET: string;
  // هوش مصنوعی — برای نمره‌دهی سمت سرور سؤالات تشریحیِ تمرین مضامین (همان
  // پیکربندی exams.ts؛ اختیاری — در نبود کلید، تشریحی‌ها از مخرج نمره حذف
  // می‌شوند، نه اینکه ظالمانه صفر بگیرند).
  AI_PROVIDER_KEY?: string;
  AI_PROVIDER_URL?: string;
  AI_MODEL?: string;
};

const academy = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function me(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

// ─────────────────────────────── Books ──────────────────────────────────────

function bookJson(r: any) {
  const pdfKey = r.pdf_key ?? '';
  return {
    id: r.id,
    title: r.title,
    subject: r.subject,
    gradeId: r.grade_id,
    category: r.category,
    author: r.author,
    description: r.description,
    language: r.language,
    pdfFileName: r.pdf_file_name,
    pdfKey,
    // آدرس واقعیِ قابل‌دانلود فایل — از همان endpoint عمومی R2 (`GET /files/*`)
    // که برای عکس پروفایل و فایل‌های صوتی هم استفاده می‌شود.
    fileUrl: pdfKey ? `/files/${pdfKey}` : null,
    fileSizeMb: r.file_size_mb,
    pageCount: r.page_count,
    coverIndex: r.cover_index,
    includeInRag: r.include_in_rag === 1,
    status: r.status,
    uploadedAt: r.uploaded_at,
    updatedAt: r.updated_at,
  };
}

academy.get('/academy/books', async (c) => {
  const u = await me(c);
  if (!u) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  // رفع اشکال: قبلاً همهٔ کاربران (حتی شاگردان) کتاب‌های «پیش‌نویس» را هم
  // می‌دیدند چون این Route فقط احراز هویت را چک می‌کرد، نه نقش. اکنون فقط
  // مدیر (که نمای کامل مدیریت محتوا را می‌بیند) پیش‌نویس‌ها را هم می‌بیند؛
  // بقیهٔ نقش‌ها فقط کتاب‌های منتشرشده را.
  const stmt =
    u.role === 'super_admin'
      ? c.env.DB.prepare('SELECT * FROM academy_books ORDER BY updated_at DESC')
      : c.env.DB.prepare("SELECT * FROM academy_books WHERE status = 'published' ORDER BY updated_at DESC");
  const { results } = await stmt.all<any>();
  return c.json({ books: results.map(bookJson) });
});

academy.post('/academy/books', async (c) => {
  const u = await me(c);
  if (!u || u.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req.json<Record<string, any>>().catch(() => null);
  if (!b) return c.json(fail('BAD_REQUEST', 'بدنه نامعتبر', 'Invalid body', 'ناسم متن', 'Contenu invalide'), 400);
  const id = String(b.id ?? '').trim() || `lb_${Date.now()}`;
  // نکتهٔ مهم: `pdf_key` عمداً از بدنهٔ کلاینت خوانده نمی‌شود — چون
  // INSERT OR REPLACE کل ردیف را جایگزین می‌کند و اگر این ستون این‌جا هم
  // از روی ورودی کلاینت نوشته می‌شد، هر ذخیرهٔ سادهٔ متادیتا (عنوان/توضیحات
  // و…) می‌توانست کلید فایل واقعیِ آپلودشده را پاک کند. تنها مسیر مجاز برای
  // تغییر آن، Endpoint اختصاصیِ `POST /academy/books/:id/pdf` است.
  await c.env.DB.prepare(
    `INSERT OR REPLACE INTO academy_books
       (id, title, subject, grade_id, category, author, description, language,
        pdf_file_name, file_size_mb, page_count, cover_index, include_in_rag, status,
        pdf_key, uploaded_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
        COALESCE((SELECT pdf_key FROM academy_books WHERE id = ?), ''),
        COALESCE((SELECT uploaded_at FROM academy_books WHERE id = ?), datetime('now')),
        datetime('now'))`,
  )
    .bind(
      id,
      String(b.title ?? ''),
      String(b.subject ?? ''),
      Number(b.gradeId ?? 0),
      String(b.category ?? ''),
      String(b.author ?? ''),
      String(b.description ?? ''),
      String(b.language ?? 'دری'),
      String(b.pdfFileName ?? ''),
      Number(b.fileSizeMb ?? 0),
      Number(b.pageCount ?? 0),
      Number(b.coverIndex ?? 0),
      b.includeInRag ? 1 : 0,
      b.status === 'published' ? 'published' : 'draft',
      id, // برای COALESCE ستون pdf_key
      id, // برای COALESCE ستون uploaded_at
    )
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM academy_books WHERE id = ?').bind(id).first<any>();
  return c.json({ book: bookJson(row) }, 201);
});

academy.delete('/academy/books/:id', async (c) => {
  const u = await me(c);
  if (!u || u.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const id = c.req.param('id');
  const row = await c.env.DB.prepare('SELECT pdf_key FROM academy_books WHERE id = ?').bind(id).first<{ pdf_key: string }>();
  if (row?.pdf_key) await c.env.BUCKET.delete(row.pdf_key);
  await c.env.DB.prepare('DELETE FROM academy_books WHERE id = ?').bind(id).run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: u.sub,
      actorRole: u.role,
      actionType: 'content_delete',
      targetTable: 'academy_books',
      targetId: id,
      ipAddress: clientIp(c),
      priority: 'high',
    }),
  );
  return c.json({ success: true });
});

// ─────────────────────── آپلود واقعیِ فایل پی‌دی‌اف کتاب (R2) ───────────────
// بدنه = بایت‌های خام پی‌دی‌اف (همان الگوی `POST /users/me/avatar` در
// media.ts)؛ نام فایل در Query String (`?fileName=`) ارسال می‌شود. قبلاً این
// مرحله کاملاً شبیه‌سازی بود — نه فایلی روی سرور ذخیره می‌شد نه شاگردان
// می‌توانستند واقعاً دانلود کنند.
academy.post('/academy/books/:id/pdf', async (c) => {
  const u = await me(c);
  if (!u || u.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const id = c.req.param('id');
  const exists = await c.env.DB.prepare('SELECT id FROM academy_books WHERE id = ?').bind(id).first();
  if (!exists) return c.json(fail('NOT_FOUND', 'کتاب یافت نشد', 'Book not found', 'کتاب ونه موندل شو', 'Livre introuvable'), 404);
  const fileName = c.req.query('fileName') || 'book.pdf';
  const bytes = await c.req.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > 60 * 1024 * 1024) {
    return c.json(
      fail('BAD_SIZE', 'حجم فایل باید بین ۱ بایت و ۶۰ مگابایت باشد', 'File size must be between 1 byte and 60MB', 'د فایل اندازه باید د ۱ بایت او ۶۰ میګابایټ ترمنځ وي', 'La taille du fichier doit être comprise entre 1 octet et 60 Mo'),
      400,
    );
  }
  const pdfKey = `academy-books/${id}.pdf`;
  await c.env.BUCKET.put(pdfKey, bytes, { httpMetadata: { contentType: 'application/pdf' } });
  const fileSizeMb = Math.round((bytes.byteLength / (1024 * 1024)) * 10) / 10;
  await c.env.DB.prepare(
    "UPDATE academy_books SET pdf_key = ?, pdf_file_name = ?, file_size_mb = ?, updated_at = datetime('now') WHERE id = ?",
  )
    .bind(pdfKey, fileName, fileSizeMb, id)
    .run();
  return c.json({ success: true, pdfKey, fileUrl: `/files/${pdfKey}`, fileSizeMb });
});

// ────────────────────────────── Questions ───────────────────────────────────

function questionJson(r: any) {
  let options: string[] = [];
  try {
    options = JSON.parse(r.options_json ?? '[]');
  } catch {
    options = [];
  }
  return {
    id: r.id,
    subject: r.subject,
    gradeId: r.grade_id,
    chapter: r.chapter,
    kind: r.kind,
    text: r.text,
    options,
    correctIndex: r.correct_index,
    correctBool: r.correct_bool === 1,
    modelAnswer: r.model_answer,
    points: r.points,
    status: r.status,
    aiGenerated: r.ai_generated === 1,
    createdAt: r.created_at,
  };
}

academy.get('/academy/questions', async (c) => {
  if (!(await me(c))) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM academy_questions ORDER BY created_at DESC',
  ).all<any>();
  return c.json({ questions: results.map(questionJson) });
});

academy.post('/academy/questions', async (c) => {
  const u = await me(c);
  if (!u || u.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req.json<Record<string, any>>().catch(() => null);
  if (!b) return c.json(fail('BAD_REQUEST', 'بدنه نامعتبر', 'Invalid body', 'ناسم متن', 'Contenu invalide'), 400);
  const id = String(b.id ?? '').trim() || `bq_${Date.now()}`;
  const kind = ['mcq', 'trueFalse', 'essay'].includes(b.kind) ? b.kind : 'mcq';
  await c.env.DB.prepare(
    `INSERT OR REPLACE INTO academy_questions
       (id, subject, grade_id, chapter, kind, text, options_json, correct_index,
        correct_bool, model_answer, points, status, ai_generated,
        created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
        COALESCE((SELECT created_at FROM academy_questions WHERE id = ?), datetime('now')))`,
  )
    .bind(
      id,
      String(b.subject ?? ''),
      Number(b.gradeId ?? 0),
      String(b.chapter ?? ''),
      kind,
      String(b.text ?? ''),
      JSON.stringify(Array.isArray(b.options) ? b.options : []),
      Number(b.correctIndex ?? 0),
      b.correctBool ? 1 : 0,
      String(b.modelAnswer ?? ''),
      Number(b.points ?? 1),
      b.status === 'published' ? 'published' : 'draft',
      b.aiGenerated ? 1 : 0,
      id,
    )
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM academy_questions WHERE id = ?').bind(id).first<any>();
  return c.json({ question: questionJson(row) }, 201);
});

academy.delete('/academy/questions/:id', async (c) => {
  const u = await me(c);
  if (!u || u.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const id = c.req.param('id');
  await c.env.DB.prepare('DELETE FROM academy_questions WHERE id = ?').bind(id).run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: u.sub,
      actorRole: u.role,
      actionType: 'content_delete',
      targetTable: 'academy_questions',
      targetId: id,
      ipAddress: clientIp(c),
    }),
  );
  return c.json({ success: true });
});

// ───────────────────────────── Submissions ──────────────────────────────────

function submissionJson(r: any) {
  let answers: unknown[] = [];
  try {
    answers = JSON.parse(r.answers_json ?? '[]');
  } catch {
    answers = [];
  }
  return {
    id: r.id,
    studentId: r.student_id,
    studentName: r.student_name,
    gradeId: r.grade_id,
    subject: r.subject,
    submittedAt: r.submitted_at,
    answers,
    scorePercent: r.score_percent,
    earnedPoints: r.earned_points,
    totalPoints: r.total_points,
    aiAssisted: r.ai_assisted === 1,
  };
}

academy.get('/academy/submissions', async (c) => {
  const u = await me(c);
  if (!u) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  // شاگرد فقط پاسخ‌های خودش؛ مدیر می‌تواند studentId دلخواه یا همه را ببیند.
  //
  // رفع اشکال «تمرین/آزمون عملی والد همیشه خالی است»: قبلاً `?studentId=`
  // فقط برای `super_admin` معتبر بود؛ برای والد نادیده گرفته می‌شد و
  // `target` به `u.sub` (خودِ والد، بدون هیچ رکورد تمرینی) برمی‌گشت. اکنون
  // والد هم می‌تواند (فقط برای فرزند تأییدشدهٔ خودش) پاسخ‌های تمرینی فرزندش
  // را ببیند.
  //
  // **هماهنگی با امتحانات رسمی:** قبلاً یک لینکِ تأییدنشده (یا مربوط به
  // فرزند کس دیگری) بی‌صدا به `u.sub` سقوط می‌کرد — یعنی والدِ غیرمجاز به‌جای
  // خطای صریح، فقط یک لیست خالیِ گمراه‌کننده می‌گرفت (که غیرقابل‌تشخیص از
  // «فرزند هنوز تمرین نکرده» بود). اکنون دقیقاً مثل الگوی `exams.ts`
  // (`GET /exams/my-results`)، تلاش برای دیدن یک فرزندِ لینک‌نشده صراحتاً
  // ۴۰۳ برمی‌گرداند تا رفتار دو داشبورد (امتحانات رسمی و تمرین مضامین)
  // کاملاً هماهنگ باشد.
  const requested = c.req.query('studentId')?.trim();
  let target: string | undefined = u.sub;
  if (requested && requested !== u.sub) {
    if (u.role === 'super_admin') {
      target = requested;
    } else if (u.role === 'parent') {
      const link = await c.env.DB.prepare(
        "SELECT 1 FROM parent_student_links WHERE parent_user_id = ? AND student_user_id = ? AND status = 'approved'",
      )
        .bind(u.sub, requested)
        .first();
      if (!link) {
        return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
      }
      target = requested;
    } else {
      return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
    }
  } else if (!requested && u.role === 'super_admin') {
    target = undefined; // برای مدیر بدون studentId یعنی «همه» (رفتار قبلی حفظ شد)
  }
  let stmt;
  if (target) {
    stmt = c.env.DB.prepare(
      'SELECT * FROM academy_submissions WHERE student_id = ? ORDER BY submitted_at DESC',
    ).bind(target);
  } else {
    stmt = c.env.DB.prepare('SELECT * FROM academy_submissions ORDER BY submitted_at DESC');
  }
  const { results } = await stmt.all<any>();
  return c.json({ submissions: results.map(submissionJson) });
});

// رفع اشکال امنیتی/هماهنگی «تمرین مضامین به نمرهٔ ارسالی کلاینت اعتماد
// می‌کند»: قبلاً `scorePercent`/`earnedPoints`/`totalPoints` و حتی
// درستی/نادرستیِ تک‌تک سؤالات (`isCorrect`/`awardedPoints`/`correctIndex`)
// عیناً از بدنهٔ کلاینت خوانده و ذخیره می‌شد — یعنی هر کلاینتِ دستکاری‌شده
// (یا حتی یک درخواست HTTP دستی) می‌توانست بدون پاسخ‌دادن به هیچ سؤالی،
// نمرهٔ ۱۰۰٪ برای خودش ثبت کند. اکنون دقیقاً هماهنگ با امتحانات رسمی
// (`POST /exams/:examId/submit`)، سرور فقط «کدام سؤال چه پاسخی گرفته»
// (`questionId` + `chosenIndex`/`chosenBool`/`essayText`) را از کلاینت
// می‌پذیرد، خودِ سؤالات واقعی را از `academy_questions` می‌خواند، و نمره
// را خودش محاسبه می‌کند — کلاینت فقط برای «تجربهٔ فوریِ آفلاین» ممکن است
// همان مقادیر را دوباره بفرستد، ولی سرور هرگز به آن‌ها اعتماد نمی‌کند.
academy.post('/academy/submissions', async (c) => {
  const u = await me(c);
  if (!u) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const b = await c.req.json<Record<string, any>>().catch(() => null);
  if (!b) return c.json(fail('BAD_REQUEST', 'بدنه نامعتبر', 'Invalid body', 'ناسم متن', 'Contenu invalide'), 400);
  const id = String(b.id ?? '').trim() || `sub_${Date.now()}_${uid().slice(0, 6)}`;
  // شاگرد فقط به نام خودش ثبت می‌کند (ضد جعل).
  const studentId = u.role === 'super_admin' ? String(b.studentId ?? u.sub) : u.sub;

  const rawAnswers: Array<Record<string, any>> = Array.isArray(b.answers) ? b.answers : [];
  const questionIds = rawAnswers
    .map((a) => String(a?.questionId ?? '').trim())
    .filter((qid) => qid.length > 0);

  // خودِ سؤالات (متن، گزینه‌ها، پاسخ صحیح، امتیاز) را از دیتابیس می‌خوانیم —
  // نه از بدنهٔ کلاینت — تا هیچ‌کدام قابل جعل نباشند.
  const questionMap = new Map<string, any>();
  if (questionIds.length > 0) {
    const placeholders = questionIds.map(() => '?').join(',');
    const { results } = await c.env.DB.prepare(
      `SELECT * FROM academy_questions WHERE id IN (${placeholders})`,
    )
      .bind(...questionIds)
      .all<any>();
    for (const r of results) questionMap.set(r.id, r);
  }

  const essayItems: Array<{ id: string; text: string; modelAnswer: string; studentAnswer: string }> = [];
  // پیش‌نویسِ رکورد هر پاسخ — سؤالات تشریحی بعداً (پس از نمره‌دهی AI) کامل می‌شوند.
  const drafts: Array<{
    questionId: string;
    questionText: string;
    kind: string;
    options: string[];
    chosenIndex: number | null;
    chosenBool: boolean | null;
    essayText: string | null;
    correctIndex: number | null;
    correctBool: boolean | null;
    modelAnswer: string;
    maxPoints: number;
    awardedPoints: number;
    isCorrect: boolean | null;
    aiFeedback: string;
  }> = [];

  for (const a of rawAnswers) {
    const qid = String(a?.questionId ?? '').trim();
    const q = questionMap.get(qid);
    if (!q) continue; // سؤالِ ناموجود/حذف‌شده — نادیده گرفته می‌شود، نه اینکه امتیاز جعلی بگیرد.
    let options: string[] = [];
    try {
      options = JSON.parse(q.options_json ?? '[]');
    } catch {
      options = [];
    }
    const maxPoints = Number(q.points ?? 1);

    if (q.kind === 'mcq') {
      const chosenIndex = Number.isInteger(a?.chosenIndex) ? Number(a.chosenIndex) : null;
      const correct = chosenIndex !== null && chosenIndex === q.correct_index;
      drafts.push({
        questionId: qid,
        questionText: q.text,
        kind: 'mcq',
        options,
        chosenIndex,
        chosenBool: null,
        essayText: null,
        correctIndex: q.correct_index,
        correctBool: null,
        modelAnswer: '',
        maxPoints,
        awardedPoints: correct ? maxPoints : 0,
        isCorrect: correct,
        aiFeedback: '',
      });
    } else if (q.kind === 'trueFalse') {
      const chosenBool = typeof a?.chosenBool === 'boolean' ? (a.chosenBool as boolean) : null;
      const correctBool = q.correct_bool === 1;
      const correct = chosenBool !== null && chosenBool === correctBool;
      drafts.push({
        questionId: qid,
        questionText: q.text,
        kind: 'trueFalse',
        options: [],
        chosenIndex: null,
        chosenBool,
        essayText: null,
        correctIndex: null,
        correctBool,
        modelAnswer: '',
        maxPoints,
        awardedPoints: correct ? maxPoints : 0,
        isCorrect: correct,
        aiFeedback: '',
      });
    } else {
      // essay — نمره‌دهی نهایی بعد از فراخوانی AI (پایین‌تر) انجام می‌شود.
      const essayText = String(a?.essayText ?? '').trim();
      if (essayText.length > 0) {
        essayItems.push({ id: qid, text: q.text, modelAnswer: q.model_answer ?? '', studentAnswer: essayText });
      }
      drafts.push({
        questionId: qid,
        questionText: q.text,
        kind: 'essay',
        options: [],
        chosenIndex: null,
        chosenBool: null,
        essayText: essayText.length > 0 ? essayText : null,
        correctIndex: null,
        correctBool: null,
        modelAnswer: q.model_answer ?? '',
        maxPoints,
        awardedPoints: 0, // پایین‌تر (در صورت وجود پاسخ + AI در دسترس) به‌روز می‌شود.
        isCorrect: null,
        aiFeedback: '',
      });
    }
  }

  const hasEssay = drafts.some((d) => d.kind === 'essay');
  let aiGraded = false;
  if (essayItems.length > 0) {
    const graded = await gradeEssaysWithAi(c.env, essayItems);
    if (graded) {
      aiGraded = true;
      for (const d of drafts) {
        if (d.kind !== 'essay' || !d.essayText) continue;
        const g = graded.get(d.questionId);
        if (g) {
          d.awardedPoints = Math.round(g.score * d.maxPoints * 10) / 10;
          d.isCorrect = g.score >= 0.5;
          d.aiFeedback = g.feedback;
        }
      }
    }
  }

  // مخرجِ نمره: سؤالات بسته همیشه حساب می‌شوند؛ سؤالات تشریحی فقط اگر واقعاً
  // نمره‌دهی شدند (AI در دسترس بود) — تا در نبود AI، شاگرد ناعادلانه به‌خاطر
  // سؤالی که اصلاً نمره نگرفته، امتیاز از دست ندهد (همان الگوی امتحانات رسمی).
  let earnedPoints = 0;
  let totalPoints = 0;
  for (const d of drafts) {
    if (d.kind === 'essay' && !aiGraded) continue;
    earnedPoints += d.awardedPoints;
    totalPoints += d.maxPoints;
  }
  const scorePercent = totalPoints === 0 ? 0 : (earnedPoints / totalPoints) * 100;
  const roundedScore = Math.round(scorePercent * 10) / 10;
  const roundedEarned = Math.round(earnedPoints * 10) / 10;

  const answersJson = drafts.map((d) => ({
    questionId: d.questionId,
    questionText: d.questionText,
    kind: d.kind,
    options: d.options,
    chosenIndex: d.chosenIndex,
    chosenBool: d.chosenBool,
    essayText: d.essayText,
    correctIndex: d.correctIndex,
    correctBool: d.correctBool,
    modelAnswer: d.modelAnswer,
    awardedPoints: d.awardedPoints,
    maxPoints: d.maxPoints,
    isCorrect: d.isCorrect,
    aiFeedback: d.aiFeedback,
  }));

  await c.env.DB.prepare(
    `INSERT OR REPLACE INTO academy_submissions
       (id, student_id, student_name, grade_id, subject, submitted_at, answers_json,
        score_percent, earned_points, total_points, ai_assisted)
     VALUES (?, ?, ?, ?, ?, datetime('now'), ?, ?, ?, ?, ?)`,
  )
    .bind(
      id,
      studentId,
      String(b.studentName ?? ''),
      Number(b.gradeId ?? 0),
      String(b.subject ?? ''),
      JSON.stringify(answersJson),
      roundedScore,
      roundedEarned,
      totalPoints,
      hasEssay ? 1 : 0,
    )
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM academy_submissions WHERE id = ?').bind(id).first<any>();
  return c.json({ submission: submissionJson(row) }, 201);
});

export default academy;
