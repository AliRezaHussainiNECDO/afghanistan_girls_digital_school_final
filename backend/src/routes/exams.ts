/**
 * routes/exams.ts — امتحانات، نمره‌دهی و گواهی‌نامه (بخش ۷/۸ سند).
 *
 * Endpointها (زیر `/api/v1`):
 *   GET  /exams/available                 لیست امتحانات منتشرشده (صنف کاربر)
 *   GET  /exams/:examId/questions         سؤالات بدون پاسخ صحیح (بخش ۷.۲)
 *   POST /exams/:examId/submit            نمره‌دهی سمت سرور + ثبت تلاش
 *   GET  /students/:studentId/certificates
 *   POST /admin/certificates              صدور گواهی‌نامه (مدیر)
 *   DELETE /admin/certificates/:id        ابطال گواهی‌نامه (مدیر)
 *   GET  /certificates/verify/:serial     صفحهٔ عمومی تأیید اصالت (بدون نیاز به ورود —
 *                                          پشت QR روی خودِ سرتیفیکت؛ برای اعتبار بین‌المللی)
 *
 *   -- مدیریت امتحانات/سؤالات (فقط مدیر — رفع اشکال: قبلاً هیچ راهی برای
 *      ساخت امتحان/سؤال از داخل برنامه وجود نداشت، پس امتحان «نهایی» برای
 *      هیچ صنفی هرگز وجود نداشت و سیستم ارتقا عملاً غیرقابل‌دسترس بود) --
 *   GET    /admin/exams                       لیست همهٔ امتحانات (همهٔ وضعیت‌ها)
 *   POST   /admin/exams                       ایجاد/ویرایش امتحان
 *   PATCH  /admin/exams/:id/status             تغییر وضعیت (draft/published/closed)
 *   DELETE /admin/exams/:id                    حذف امتحان + سؤالات/تلاش‌های وابسته
 *   GET    /admin/exams/:examId/questions      سؤالات با پاسخ صحیح (فقط مدیر)
 *   POST   /admin/exams/:examId/questions      ایجاد/ویرایش سؤال
 *   DELETE /admin/questions/:id                حذف سؤال
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { promoteIfEligible, PROMOTION_EXAM_PASS_PERCENT } from '../lib/progress';
import { sendPushToUser } from '../lib/push';
import { logAudit, clientIp } from '../lib/audit';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
  // هوش مصنوعی — همان پیکربندی ai.ts (سازگار با Chat Completions استاندارد):
  // برای «تولید سؤال با AI» و «نمره‌دهی سؤالات تشریحی». اختیاری — در نبود
  // کلید، تولید سؤال 503 برمی‌گرداند و تشریحی‌ها از مخرج نمره حذف می‌شوند.
  AI_PROVIDER_KEY?: string;
  AI_PROVIDER_URL?: string;
  AI_MODEL?: string;
};

const exams = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function auth(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

const TYPE_MAP: Record<string, string> = {
  daily_quiz: 'dailyQuiz',
  homework: 'homework',
  monthly: 'monthly',
  final: 'finalExam',
};

// انواع سؤال (migration 0030): چهارگزینه‌ای | صحیح‌وغلط | تشریحی.
const QUESTION_TYPES = new Set(['mcq', 'true_false', 'essay']);
const TRUE_FALSE_OPTIONS = ['صحیح', 'غلط'];

// ─────────────── فراخوانی LLM (همان قرارداد ai.ts — JSON خالص) ───────────────
async function callAiJson(env: Bindings, systemPrompt: string, userPrompt: string, maxTokens: number): Promise<any> {
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
  return JSON.parse(text);
}

/// نمره‌دهی تشریحی با AI — ورودی: سؤالات تشریحی + پاسخ نمونه + پاسخ شاگرد.
/// خروجی: Map از questionId → {score: 0..1, feedback}. در نبود کلید یا خطا،
/// null برمی‌گردد تا تشریحی‌ها از مخرج نمره حذف شوند (نه اینکه ظالمانه صفر
/// حساب شوند و نه رایگان نمرهٔ کامل بگیرند).
async function gradeEssaysWithAi(
  env: Bindings,
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

// ────────────────────────── لیست امتحانات موجود ─────────────────────────────

exams.get('/exams/available', async (c) => {
  const me = await auth(c);
  // اگر توکن باشد، فقط امتحانات صنف کاربر؛ در غیر این صورت همه (برای تست).
  let grade = 0;
  if (me) {
    const u = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?')
      .bind(me.sub)
      .first<{ current_grade: number | null }>();
    grade = u?.current_grade ?? 0;
  }
  // رفع اشکال: قبلاً این فهرست هیچ اطلاعی از تلاش‌های قبلیِ همین شاگرد
  // نمی‌داد، پس رابط کاربری همیشه فقط دکمهٔ «شروع» نشان می‌داد — حتی برای
  // امتحانی که شاگرد قبلاً با نمرهٔ خوب کامیاب شده بود. اکنون بهترین نمرهٔ
  // قبلیِ همین کاربر هم همراه هر امتحان برگردانده می‌شود (پارامتری — نه
  // درج مستقیم در متن SQL — تا از تزریق SQL جلوگیری شود).
  const userIdParam = me?.sub ?? '';
  const bestScoreSql = me
    ? `, (SELECT MAX(a.score_percent) FROM exam_attempts a WHERE a.exam_id = e.id AND a.user_id = ?) AS best_score`
    : '';
  const query = grade
    ? c.env.DB.prepare(
        `SELECT e.id, e.type, e.duration_minutes, e.grade_number, s.name_fa AS subject_name_fa,
           (SELECT COUNT(*) FROM questions q WHERE q.exam_id = e.id) AS question_count${bestScoreSql}
         FROM exams e JOIN subjects s ON s.id = e.subject_id
         WHERE e.status='published' AND e.grade_number = ? ORDER BY e.created_at DESC`,
      ).bind(...(me ? [userIdParam] : []), grade)
    : c.env.DB.prepare(
        `SELECT e.id, e.type, e.duration_minutes, e.grade_number, s.name_fa AS subject_name_fa,
           (SELECT COUNT(*) FROM questions q WHERE q.exam_id = e.id) AS question_count${bestScoreSql}
         FROM exams e JOIN subjects s ON s.id = e.subject_id
         WHERE e.status='published' ORDER BY e.created_at DESC`,
      ).bind(...(me ? [userIdParam] : []));
  const { results } = await query.all<any>();
  const list = results.map((e) => ({
    id: e.id,
    subjectNameFa: e.subject_name_fa,
    type: TYPE_MAP[e.type as string] ?? 'dailyQuiz',
    durationMinutes: e.duration_minutes,
    questionCount: e.question_count,
    gradeNumber: e.grade_number,
    bestScorePercent: e.best_score ?? null,
    passed: (e.best_score ?? 0) >= PROMOTION_EXAM_PASS_PERCENT,
  }));
  return c.json({ exams: list });
});

// ─────────────────────────── سؤالات (بدون پاسخ) ─────────────────────────────

exams.get('/exams/:examId/questions', async (c) => {
  const examId = c.req.param('examId');
  const { results } = await c.env.DB.prepare(
    'SELECT id, text, options, q_type FROM questions WHERE exam_id = ? ORDER BY order_index',
  )
    .bind(examId)
    .all<{ id: string; text: string; options: string; q_type: string }>();
  const list = results.map((q) => ({
    id: q.id,
    text: q.text,
    qType: QUESTION_TYPES.has(q.q_type) ? q.q_type : 'mcq',
    options: q.q_type === 'essay' ? [] : JSON.parse(q.options || '[]'),
    // correctIndex و answer_text عمداً فرستاده نمی‌شوند (بخش ۷.۲ — نمره‌دهی
    // فقط سمت سرور؛ پاسخ نمونهٔ تشریحی هم کلید نمره‌دهی است).
  }));
  return c.json({ questions: list });
});

// ─────────────────────── ارسال پاسخ‌ها + نمره‌دهی سرور ───────────────────────

exams.post('/exams/:examId/submit', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const examId = c.req.param('examId');
  const body = await c.req
    .json<{ answers?: Record<string, number>; textAnswers?: Record<string, string> }>()
    .catch(() => null);
  const answers = body?.answers ?? {};
  const textAnswers = body?.textAnswers ?? {};

  const { results } = await c.env.DB.prepare(
    'SELECT id, text, correct_index, q_type, answer_text FROM questions WHERE exam_id = ?',
  )
    .bind(examId)
    .all<{ id: string; text: string; correct_index: number; q_type: string; answer_text: string | null }>();
  if (results.length === 0) {
    return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found', 'ازموینه ونه موندل شوه', 'Examen introuvable'), 404);
  }

  // ۱) سؤالات بسته (چهارگزینه‌ای + صحیح‌وغلط) — نمره‌دهی قطعی سمت سرور.
  const closed = results.filter((q) => q.q_type !== 'essay');
  const essays = results.filter((q) => q.q_type === 'essay');
  let correct = 0;
  for (const q of closed) {
    if (answers[q.id] === q.correct_index) correct++;
  }

  // ۲) سؤالات تشریحی — نمره‌دهی AI (0..1 برای هر سؤال). در نبود AI یا خطا،
  //    تشریحی‌ها از مخرج حذف می‌شوند تا نمرهٔ شاگرد ناعادلانه نشود.
  let points = correct;
  let total = closed.length;
  const essayRecords: Array<{ questionId: string; answer: string; score: number | null; feedback: string }> = [];
  if (essays.length > 0) {
    const items = essays.map((q) => ({
      id: q.id,
      text: q.text,
      modelAnswer: q.answer_text ?? '',
      studentAnswer: String(textAnswers[q.id] ?? '').trim(),
    }));
    const graded = await gradeEssaysWithAi(c.env, items.filter((i) => i.studentAnswer.length > 0));
    for (const item of items) {
      const g = item.studentAnswer.length > 0 ? graded?.get(item.id) : { score: 0, feedback: 'بدون پاسخ' };
      if (g) {
        points += g.score;
        total += 1;
        // سؤال با نمرهٔ ≥ نصف، «صحیح» شمرده می‌شود (برای شمارندهٔ correct).
        if (g.score >= 0.5) correct++;
        essayRecords.push({ questionId: item.id, answer: item.studentAnswer, score: g.score, feedback: g.feedback });
      } else {
        // AI در دسترس نبود — پاسخ ذخیره می‌شود ولی در نمره حساب نمی‌شود.
        essayRecords.push({ questionId: item.id, answer: item.studentAnswer, score: null, feedback: '' });
      }
    }
  }
  const score = total === 0 ? 0 : (points / total) * 100;

  const roundedScore = Math.round(score * 10) / 10;
  // ثبت تلاش + یک اعلان نتیجه (تا اعلان‌ها از رویداد واقعی پر شوند — بخش ۱۳.۱).
  const examRow = await c.env.DB.prepare('SELECT title, type, grade_number FROM exams WHERE id = ?')
    .bind(examId)
    .first<{ title: string; type: string; grade_number: number }>();
  await c.env.DB.batch([
    c.env.DB.prepare(
      'INSERT INTO exam_attempts (id, exam_id, user_id, score_percent, correct_count, total_count, essay_answers) VALUES (?, ?, ?, ?, ?, ?, ?)',
    ).bind(uid(), examId, me.sub, score, correct, total, essayRecords.length > 0 ? JSON.stringify(essayRecords) : null),
    c.env.DB.prepare(
      "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind, related_id) VALUES (?, ?, ?, ?, 'medium', 'exam', ?)",
    ).bind(
      uid(),
      me.sub,
      'نتیجهٔ امتحان',
      `نمرهٔ شما در «${examRow?.title ?? 'امتحان'}»: ${roundedScore}٪ (${correct} از ${total})`,
      examId,
    ),
  ]);
  c.executionCtx.waitUntil(
    sendPushToUser(c.env, me.sub, 'نتیجهٔ امتحان', `نمرهٔ شما در «${examRow?.title ?? 'امتحان'}»: ${roundedScore}٪ (${correct} از ${total})`),
  );

  // رفع اشکال ارتقای صنف: قبلاً ارتقا فقط در ذخیرهٔ محلی گوشی شبیه‌سازی
  // می‌شد. اکنون اگر این یک امتحانِ «نهایی» بود، بلافاصله شرایط ارتقای
  // واقعی (تکمیل تمام مضامین + کامیابی در امتحان) روی سرور بررسی می‌شود.
  let promotion: { promoted: boolean; newGrade: number | null } = { promoted: false, newGrade: null };
  if (examRow?.type === 'final') {
    promotion = await promoteIfEligible(c.env.DB, me.sub);
  }

  return c.json({
    scorePercent: Math.round(score * 10) / 10,
    correctCount: correct,
    totalCount: total,
    promoted: promotion.promoted,
    newGrade: promotion.newGrade,
  });
});

// ──────────────────────────── گواهی‌نامه‌ها ──────────────────────────────────

exams.get('/students/:studentId/certificates', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const requestedId = c.req.param('studentId');

  // رفع اشکال واقعی: قبلاً فقط دو حالت شناخته می‌شد — «مدیر» (هر studentId
  // مجاز) یا «هرکس دیگر» (همیشه فقط شناسهٔ خودش، صرف‌نظر از پارامتر URL).
  // یعنی وقتی یک والد با شناسهٔ واقعی فرزندش این Endpoint را صدا می‌زد
  // (دقیقاً همان‌طور که «گواهی‌نامه‌های فرزند» در داشبورد والدین انجام
  // می‌دهد)، سرور بی‌صدا شناسهٔ خودِ والد را جایگزین می‌کرد — چون والد هیچ
  // گواهی‌ای ندارد، همیشه فهرست خالی برمی‌گشت، حتی وقتی فرزند واقعاً گواهی
  // داشت. اکنون مثل بقیهٔ Endpointهای مشابه (curriculum.ts/parents.ts)،
  // والدِ لینک‌شدهٔ تأییدشده هم مجاز است — فقط برای همان فرزند مشخص.
  let target: string;
  if (me.role === 'super_admin') {
    target = requestedId;
  } else if (me.role === 'parent' && requestedId !== me.sub) {
    const link = await c.env.DB.prepare(
      "SELECT 1 FROM parent_student_links WHERE parent_user_id=? AND student_user_id=? AND status='approved'",
    )
      .bind(me.sub, requestedId)
      .first();
    if (!link) {
      return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
    }
    target = requestedId;
  } else {
    // شاگرد (یا هر نقش دیگر): همیشه فقط گواهی‌نامهٔ خودش — صرف‌نظر از اینکه
    // در URL چه شناسه‌ای فرستاده شده (شامل مقدار نمادین «me»، بخش پایین‌تر).
    target = me.sub;
  }

  const { results } = await c.env.DB.prepare(
    'SELECT * FROM certificates WHERE student_id = ? ORDER BY issued_at DESC',
  )
    .bind(target)
    .all<any>();
  return c.json({ certificates: results.map(certJson) });
});

exams.post('/admin/certificates', async (c) => {
  const me = await auth(c);
  // رفع اشکال امنیتی: قبلاً این Endpoint فقط بررسی می‌کرد کاربر وارد شده
  // باشد (بدون بررسی نقش) — یعنی هر شاگرد/والد/استاد می‌توانست برای خودش یا
  // هر studentId دلخواه گواهی‌نامهٔ فارغ‌التحصیلی صادر کند. مثل بقیهٔ
  // Endpointهای `/admin/*` این بخش، باید فقط مدیر ارشد مجاز باشد.
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req.json<any>().catch(() => null);
  if (!b?.studentId) return c.json(fail('BAD_REQUEST', 'ورودی ناقص', 'Missing fields', 'نیمګړی ننوت', 'Entrée incomplète'), 400);
  const id = uid();
  const grade = Number(b.grade ?? 7);
  const serial = `AGDS-${grade}-${Date.now()}`;
  await c.env.DB.prepare(
    `INSERT INTO certificates (id, serial, student_id, student_name, grade, year_label, average, honor, issued_by)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(
      id,
      serial,
      String(b.studentId),
      String(b.studentName ?? ''),
      grade,
      String(b.yearLabel ?? ''),
      Number(b.average ?? 0),
      String(b.honor ?? ''),
      'مدیریت مکتب',
    )
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM certificates WHERE id = ?').bind(id).first<any>();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: me.sub,
      actorRole: me.role,
      actionType: 'certificate_issue',
      targetTable: 'certificates',
      targetId: id,
      afterValue: { studentId: b.studentId, serial, grade, honor: b.honor ?? '' },
      ipAddress: clientIp(c),
      priority: 'high',
    }),
  );
  return c.json({ certificate: certJson(row) }, 201);
});

exams.delete('/admin/certificates/:id', async (c) => {
  const me = await auth(c);
  // رفع اشکال امنیتی: مثل بالا، ابطال گواهی هم قبلاً فقط به ورود‌شدن نیاز
  // داشت، نه به نقش مدیر.
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const id = c.req.param('id');
  const before = await c.env.DB.prepare('SELECT student_id, serial FROM certificates WHERE id = ?').bind(id).first<{ student_id: string; serial: string }>();
  await c.env.DB.prepare('DELETE FROM certificates WHERE id = ?').bind(id).run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: me.sub,
      actorRole: me.role,
      actionType: 'certificate_revoke',
      targetTable: 'certificates',
      targetId: id,
      beforeValue: before ? { studentId: before.student_id, serial: before.serial } : null,
      ipAddress: clientIp(c),
      priority: 'high',
    }),
  );
  return c.json({ success: true });
});

// ───────────────────── تأیید عمومی اصالت گواهی‌نامه (QR) ─────────────────────
// طبق درخواست کاربر برای اعتبار بین‌المللی: روی هر سرتیفیکت یک QR چاپ می‌شود
// که به همین صفحه لینک می‌شود — هر دانشگاه/کارفرما بدون نیاز به حساب کاربری
// می‌تواند اصالت سند را آنلاین بررسی کند (همان الگوی Coursera/edX). صفحه
// عمداً حداقلی است: فقط اطلاعاتی که خودِ سرتیفیکت چاپی هم نشان می‌دهد (نه
// اطلاعات حساس اضافه‌ای مثل ایمیل/تلفن).
function escapeHtml(s: string): string {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function certificateVerifyPage(found: boolean, cert?: any): string {
  const brand = 'مکتب دیجیتال دختران افغانستان';
  if (!found) {
    return `<!doctype html>
<html dir="rtl" lang="fa"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>تأیید سرتیفیکت — ${brand}</title></head>
<body style="margin:0;background:#f4f6f8;font-family:Tahoma,'Segoe UI',sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;">
<div style="background:#fff;border:1px solid #e3e8ee;border-radius:12px;padding:40px 32px;max-width:440px;text-align:center;">
<div style="font-size:48px;">❌</div>
<h2 style="color:#b3261e;margin:16px 0 8px;">این سرتیفیکت یافت نشد یا نامعتبر/باطل‌شده است</h2>
<p style="color:#7b8794;font-size:13px;">شمارهٔ سریال واردشده در سامانهٔ ${brand} ثبت نیست.</p>
</div></body></html>`;
  }
  const c = cert;
  const issuedAt = c.issued_at ? String(c.issued_at).slice(0, 10) : '';
  const honorLine = c.honor ? `<div style="margin-top:6px;color:#b8860b;font-weight:700;">${escapeHtml(c.honor)}</div>` : '';
  return `<!doctype html>
<html dir="rtl" lang="fa"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>تأیید سرتیفیکت — ${brand}</title></head>
<body style="margin:0;background:#f4f6f8;font-family:Tahoma,'Segoe UI',sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;padding:16px;">
<div style="background:#fff;border:1px solid #e3e8ee;border-radius:14px;padding:36px 32px;max-width:460px;width:100%;text-align:center;">
<div style="font-size:48px;">✅</div>
<h2 style="color:#1b6e4b;margin:14px 0 4px;">این سرتیفیکت اصیل و معتبر است</h2>
<p style="color:#7b8794;font-size:12.5px;margin-bottom:20px;">صادرشده توسط ${brand}</p>
<div style="text-align:right;background:#f9fafb;border:1px solid #e3e8ee;border-radius:10px;padding:16px 18px;font-size:14px;line-height:2;">
<div><b>نام شاگرد:</b> ${escapeHtml(c.student_name)}</div>
<div><b>صنف تکمیل‌شده:</b> ${escapeHtml(String(c.grade))}</div>
<div><b>سال تعلیمی:</b> ${escapeHtml(c.year_label)}</div>
<div><b>میانگین نمرات:</b> ${escapeHtml(String(c.average))}</div>
<div><b>تاریخ صدور:</b> ${escapeHtml(issuedAt)}</div>
<div><b>شمارهٔ سریال:</b> ${escapeHtml(c.serial)}</div>
${honorLine}
</div>
</div></body></html>`;
}

exams.get('/certificates/verify/:serial', async (c) => {
  const serial = c.req.param('serial');
  const row = await c.env.DB.prepare('SELECT * FROM certificates WHERE serial = ?').bind(serial).first<any>();
  return c.html(certificateVerifyPage(!!row, row));
});

function certJson(r: any) {
  return {
    id: r.id,
    serial: r.serial,
    studentId: r.student_id,
    studentName: r.student_name,
    grade: r.grade,
    yearLabel: r.year_label,
    average: r.average,
    honor: r.honor,
    issuedAt: r.issued_at,
    issuedBy: r.issued_by,
  };
}

// ═══════════ مدیریت امتحانات و سؤالات (فقط مدیر — احراز صنف نهایی) ═══════════
// قبلاً هیچ Endpointای برای ساخت/ویرایش امتحان یا سؤال وجود نداشت — تنها
// دادهٔ موجود، دو امتحانِ نمونهٔ Seed در migration 0004 برای صنف ۷ بود و
// هیچ امتحان نوع «نهایی» (final) برای هیچ صنفی وجود نداشت. این یعنی
// `promoteIfEligible` (بخش ۷.۴/lib/progress.ts) عملاً هرگز از مسیر امتحان
// واقعی قابل بررسی نبود. این بخش به مدیر اجازه می‌دهد امتحان و سؤالات آن
// را مستقیماً از داخل برنامه بسازد/ویرایش/حذف کند.

const EXAM_TYPES = new Set(['daily_quiz', 'homework', 'monthly', 'final']);
const EXAM_STATUSES = new Set(['draft', 'published', 'closed']);

function adminExamJson(r: any) {
  return {
    id: r.id,
    subjectId: r.subject_id,
    subjectNameFa: r.subject_name_fa,
    gradeNumber: r.grade_number,
    type: r.type,
    title: r.title,
    durationMinutes: r.duration_minutes,
    status: r.status,
    questionCount: r.question_count ?? 0,
    createdAt: r.created_at,
  };
}

const ADMIN_EXAM_SELECT = `
  SELECT e.*, s.name_fa AS subject_name_fa,
    (SELECT COUNT(*) FROM questions q WHERE q.exam_id = e.id) AS question_count
  FROM exams e JOIN subjects s ON s.id = e.subject_id`;

exams.get('/admin/exams', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const { results } = await c.env.DB.prepare(`${ADMIN_EXAM_SELECT} ORDER BY e.grade_number, e.created_at DESC`).all<any>();
  return c.json({ exams: results.map(adminExamJson) });
});

exams.post('/admin/exams', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req
    .json<{
      id?: string;
      subjectId?: string;
      gradeNumber?: number;
      type?: string;
      title?: string;
      durationMinutes?: number;
      status?: string;
    }>()
    .catch(() => null);
  const subjectId = String(b?.subjectId ?? '').trim();
  const gradeNumber = Number(b?.gradeNumber ?? 0);
  const title = String(b?.title ?? '').trim();
  const type = EXAM_TYPES.has(String(b?.type)) ? String(b!.type) : 'daily_quiz';
  const status = EXAM_STATUSES.has(String(b?.status)) ? String(b!.status) : 'draft';
  const durationMinutes = Number(b?.durationMinutes ?? 10);
  if (!subjectId || !gradeNumber || !title) {
    return c.json(fail('BAD_REQUEST', 'مضمون، صنف و عنوان لازم است', 'Missing fields', 'مضمون، ټولګی او سرلیک اړین دي', 'La matière, la classe et le titre sont requis'), 400);
  }

  const id = b?.id && String(b.id).trim().length > 0 ? String(b.id).trim() : uid();
  const existing = await c.env.DB.prepare('SELECT id FROM exams WHERE id = ?').bind(id).first();
  if (existing) {
    await c.env.DB.prepare(
      'UPDATE exams SET subject_id=?, grade_number=?, type=?, title=?, duration_minutes=?, status=? WHERE id=?',
    )
      .bind(subjectId, gradeNumber, type, title, durationMinutes, status, id)
      .run();
    const row = await c.env.DB.prepare(`${ADMIN_EXAM_SELECT} WHERE e.id = ?`).bind(id).first<any>();
    return c.json({ exam: adminExamJson(row) }, 200);
  }
  await c.env.DB.prepare(
    `INSERT INTO exams (id, subject_id, grade_number, type, title, duration_minutes, status)
     VALUES (?, ?, ?, ?, ?, ?, ?)`,
  )
    .bind(id, subjectId, gradeNumber, type, title, durationMinutes, status)
    .run();
  const row = await c.env.DB.prepare(`${ADMIN_EXAM_SELECT} WHERE e.id = ?`).bind(id).first<any>();
  return c.json({ exam: adminExamJson(row) }, 201);
});

exams.patch('/admin/exams/:id/status', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  const status = EXAM_STATUSES.has(String(b?.status)) ? String(b!.status) : 'draft';
  await c.env.DB.prepare('UPDATE exams SET status = ? WHERE id = ?').bind(status, c.req.param('id')).run();
  return c.json({ success: true });
});

exams.delete('/admin/exams/:id', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const examId = c.req.param('id');
  const before = await c.env.DB.prepare('SELECT title, subject_id, grade_number FROM exams WHERE id = ?').bind(examId).first<any>();
  await c.env.DB.prepare('DELETE FROM exam_attempts WHERE exam_id = ?').bind(examId).run();
  await c.env.DB.prepare('DELETE FROM questions WHERE exam_id = ?').bind(examId).run();
  await c.env.DB.prepare('DELETE FROM exams WHERE id = ?').bind(examId).run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: me.sub,
      actorRole: me.role,
      actionType: 'exam_delete',
      targetTable: 'exams',
      targetId: examId,
      beforeValue: before,
      ipAddress: clientIp(c),
      priority: 'high',
    }),
  );
  return c.json({ success: true });
});

// سؤالات — نسخهٔ مدیر شامل پاسخ صحیح (برخلاف /exams/:examId/questions عمومی).

exams.get('/admin/exams/:examId/questions', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const { results } = await c.env.DB.prepare(
    'SELECT id, exam_id, text, options, correct_index, order_index, q_type, answer_text FROM questions WHERE exam_id = ? ORDER BY order_index',
  )
    .bind(c.req.param('examId'))
    .all<any>();
  const list = results.map((q) => ({
    id: q.id,
    examId: q.exam_id,
    text: q.text,
    qType: QUESTION_TYPES.has(q.q_type) ? q.q_type : 'mcq',
    options: JSON.parse(q.options || '[]'),
    correctIndex: q.correct_index,
    orderIndex: q.order_index,
    answerText: q.answer_text ?? '',
  }));
  return c.json({ questions: list });
});

exams.post('/admin/exams/:examId/questions', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const examId = c.req.param('examId');
  const examExists = await c.env.DB.prepare('SELECT id FROM exams WHERE id = ?').bind(examId).first();
  if (!examExists) return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found', 'ازموینه ونه موندل شوه', 'Examen introuvable'), 404);

  const b = await c.req
    .json<{
      id?: string;
      text?: string;
      qType?: string;
      options?: string[];
      correctIndex?: number;
      orderIndex?: number;
      answerText?: string;
    }>()
    .catch(() => null);
  const text = String(b?.text ?? '').trim();
  const qType = QUESTION_TYPES.has(String(b?.qType)) ? String(b!.qType) : 'mcq';
  let options = Array.isArray(b?.options) ? b!.options!.map((o) => String(o)) : [];
  let correctIndex = Number(b?.correctIndex ?? -1);
  const answerText = String(b?.answerText ?? '').trim();

  // اعتبارسنجی بر اساس نوع سؤال (migration 0030):
  //   mcq        متن + حداقل ۲ گزینه + پاسخ صحیح معتبر
  //   true_false متن + پاسخ صحیح 0 (صحیح) یا 1 (غلط) — گزینه‌ها ثابت‌اند
  //   essay      فقط متن (پاسخ نمونهٔ اختیاری برای کلید نمره‌دهی AI)
  if (!text) {
    return c.json(fail('BAD_REQUEST', 'متن سؤال لازم است', 'Question text required', 'د پوښتنې متن اړین دی', 'Le texte de la question est requis'), 400);
  }
  if (qType === 'essay') {
    options = [];
    correctIndex = -1;
  } else if (qType === 'true_false') {
    options = [...TRUE_FALSE_OPTIONS];
    if (correctIndex !== 0 && correctIndex !== 1) {
      return c.json(fail('BAD_REQUEST', 'پاسخ صحیح سؤال صحیح/غلط باید مشخص شود', 'Invalid true/false answer', 'د سم/ناسم پوښتنې سم ځواب باید وټاکل شي', 'La réponse correcte vrai/faux doit être choisie'), 400);
    }
  } else if (options.length < 2 || correctIndex < 0 || correctIndex >= options.length) {
    return c.json(
      fail('BAD_REQUEST', 'متن سؤال، حداقل ۲ گزینه و پاسخ صحیح معتبر لازم است', 'Missing/invalid fields', 'د پوښتنې متن، لږترلږه ۲ ټاکنې او سم ځواب اړین دي', 'Le texte de la question, au moins 2 choix et une réponse correcte valide sont requis'),
      400,
    );
  }

  const id = b?.id && String(b.id).trim().length > 0 ? String(b.id).trim() : uid();
  const existing = await c.env.DB.prepare('SELECT id FROM questions WHERE id = ?').bind(id).first();
  let orderIndex = Number(b?.orderIndex ?? 0);
  if (!existing && !orderIndex) {
    const countRow = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM questions WHERE exam_id = ?')
      .bind(examId)
      .first<{ n: number }>();
    orderIndex = (countRow?.n ?? 0) + 1;
  }
  const json = { id, examId, text, qType, options, correctIndex, orderIndex, answerText };
  if (existing) {
    await c.env.DB.prepare(
      'UPDATE questions SET text=?, options=?, correct_index=?, order_index=?, q_type=?, answer_text=? WHERE id=?',
    )
      .bind(text, JSON.stringify(options), correctIndex, orderIndex, qType, answerText || null, id)
      .run();
    return c.json({ question: json }, 200);
  }
  await c.env.DB.prepare(
    'INSERT INTO questions (id, exam_id, text, options, correct_index, order_index, q_type, answer_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  )
    .bind(id, examId, text, JSON.stringify(options), correctIndex, orderIndex, qType, answerText || null)
    .run();
  return c.json({ question: json }, 201);
});

// ─────────────── تولید سؤال با هوش مصنوعی (صنف + مضمونِ خود امتحان) ───────────────
// مدیر تعداد دلخواه از هر نوع (چهارگزینه‌ای/صحیح‌وغلط/تشریحی) را انتخاب
// می‌کند؛ AI بر اساس صنف و مضمونِ همان امتحان سؤالات دری تولید و مستقیم در
// جدول `questions` ذخیره می‌کند (در ادامهٔ order_index موجود).
exams.post('/admin/exams/:examId/generate-questions', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  if (!c.env.AI_PROVIDER_KEY) {
    return c.json(fail('AI_NOT_CONFIGURED', 'موتور هوش مصنوعی سرور پیکربندی نشده است', 'AI provider not configured', 'د سرور د مصنوعي هوښیارتیا انجن تنظیم شوی نه دی', 'Le moteur d\'IA du serveur n\'est pas configuré'), 503);
  }
  const examId = c.req.param('examId');
  const exam = await c.env.DB.prepare(
    'SELECT e.grade_number, e.title, s.name_fa AS subject_name FROM exams e JOIN subjects s ON s.id = e.subject_id WHERE e.id = ?',
  )
    .bind(examId)
    .first<{ grade_number: number; title: string; subject_name: string }>();
  if (!exam) return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found', 'ازموینه ونه موندل شوه', 'Examen introuvable'), 404);

  const b = await c.req
    .json<{ mcqCount?: number; trueFalseCount?: number; essayCount?: number; topic?: string }>()
    .catch(() => null);
  const clamp = (v: unknown) => Math.max(0, Math.min(30, Math.floor(Number(v ?? 0)) || 0));
  const mcqCount = clamp(b?.mcqCount);
  const trueFalseCount = clamp(b?.trueFalseCount);
  const essayCount = clamp(b?.essayCount);
  const topic = String(b?.topic ?? '').trim();
  if (mcqCount + trueFalseCount + essayCount === 0) {
    return c.json(fail('BAD_REQUEST', 'حداقل یک سؤال انتخاب کنید', 'Choose at least one question', 'لږترلږه یوه پوښتنه وټاکئ', 'Choisissez au moins une question'), 400);
  }

  try {
    const parsed = await callAiJson(
      c.env,
      'تو یک معلم باتجربهٔ نصاب معارف افغانستان هستی و برای شاگردان دختر سؤال امتحان به زبان دری می‌سازی. فقط JSON خالص برگردان — بدون هیچ متن اضافه.',
      `برای امتحان «${exam.title}» مضمون «${exam.subject_name}» صنف ${exam.grade_number}` +
        (topic ? ` (موضوع: ${topic})` : '') +
        ` سؤال بساز:\n` +
        `- ${mcqCount} سؤال چهارگزینه‌ای (type="mcq"، دقیقاً ۴ گزینه، correctIndex از 0 تا 3)\n` +
        `- ${trueFalseCount} سؤال صحیح/غلط (type="true_false"، بدون options، correctIndex: 0 یعنی «صحیح» و 1 یعنی «غلط»)\n` +
        `- ${essayCount} سؤال تشریحی (type="essay"، بدون options، فیلد answer = پاسخ نمونهٔ کوتاه برای کلید نمره‌دهی)\n` +
        `سؤالات باید متناسب با سطح صنف ${exam.grade_number} و از نصاب معارف افغانستان باشند.\n` +
        `خروجی: آرایهٔ JSON دقیقاً به شکل [{"type":"mcq","text":"...","options":["..","..","..",".."],"correctIndex":0},{"type":"true_false","text":"...","correctIndex":1},{"type":"essay","text":"...","answer":"..."}]`,
      4000,
    );
    if (!Array.isArray(parsed) || parsed.length === 0) {
      return c.json(fail('AI_EMPTY', 'پاسخ نامعتبر از سرویس هوش مصنوعی', 'Invalid AI reply', 'د مصنوعي هوښیارتیا له خدمت نه ناسم ځواب', 'Réponse invalide du service d\'IA'), 502);
    }

    const countRow = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM questions WHERE exam_id = ?')
      .bind(examId)
      .first<{ n: number }>();
    let orderIndex = countRow?.n ?? 0;
    const saved: any[] = [];
    const statements: D1PreparedStatement[] = [];
    for (const item of parsed) {
      const qType = QUESTION_TYPES.has(String(item?.type)) ? String(item.type) : null;
      const text = String(item?.text ?? '').trim();
      if (!qType || !text) continue;
      let options: string[] = [];
      let correctIndex = -1;
      const answerText = String(item?.answer ?? '').trim();
      if (qType === 'mcq') {
        options = Array.isArray(item?.options) ? item.options.map((o: unknown) => String(o)) : [];
        correctIndex = Number(item?.correctIndex ?? -1);
        if (options.length < 2 || correctIndex < 0 || correctIndex >= options.length) continue;
      } else if (qType === 'true_false') {
        options = [...TRUE_FALSE_OPTIONS];
        correctIndex = Number(item?.correctIndex) === 1 ? 1 : 0;
      }
      orderIndex += 1;
      const id = uid();
      statements.push(
        c.env.DB.prepare(
          'INSERT INTO questions (id, exam_id, text, options, correct_index, order_index, q_type, answer_text) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        ).bind(id, examId, text, JSON.stringify(options), correctIndex, orderIndex, qType, answerText || null),
      );
      saved.push({ id, examId, text, qType, options, correctIndex, orderIndex, answerText });
    }
    if (statements.length === 0) {
      return c.json(fail('AI_EMPTY', 'هیچ سؤال معتبری تولید نشد', 'No valid questions generated', 'هیڅ سمه پوښتنه جوړه نشوه', 'Aucune question valide générée'), 502);
    }
    await c.env.DB.batch(statements);
    c.executionCtx.waitUntil(
      logAudit(c.env.DB, {
        actorId: me.sub,
        actorRole: me.role,
        actionType: 'ai_invocation',
        targetTable: 'questions',
        targetId: examId,
        ipAddress: clientIp(c),
        detail: { purpose: 'exam_question_generation', mcqCount, trueFalseCount, essayCount, topic, generated: saved.length },
      }),
    );
    return c.json({ questions: saved }, 201);
  } catch (e: any) {
    return c.json(
      { ...fail('AI_UPSTREAM_ERROR', 'خطا از سرویس هوش مصنوعی', 'AI upstream error', 'د مصنوعي هوښیارتیا له خدمت نه تېروتنه', 'Erreur du service d\'IA'), detail: String(e?.message ?? e).slice(0, 200) },
      502,
    );
  }
});

exams.delete('/admin/questions/:id', async (c) => {
  const me = await auth(c);
  if (!me || me.role !== 'super_admin') return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const id = c.req.param('id');
  await c.env.DB.prepare('DELETE FROM questions WHERE id = ?').bind(id).run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: me.sub,
      actorRole: me.role,
      actionType: 'content_delete',
      targetTable: 'questions',
      targetId: id,
      ipAddress: clientIp(c),
    }),
  );
  return c.json({ success: true });
});

export default exams;
