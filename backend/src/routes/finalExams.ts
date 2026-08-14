/**
 * routes/finalExams.ts — امتحان فاینل چندمضمونهٔ صنف (migration 0041،
 * lib/finalExam.ts). طبق درخواست صریح صاحب پروژه:
 *   - یک امتحان واحد برای کل صنف (نه یک امتحان جدا برای هر مضمون).
 *   - حداقل ۳ سؤال از هر مضمون، در مجموع حدود ۳۰ سؤال.
 *   - هم مدیر می‌تواند دستی بسازد، هم با هوش مصنوعی یک‌جا برای همهٔ مضامین.
 *   - اگر شاگرد قبول نشد (کمتر از PROMOTION_EXAM_PASS_PERCENT)، دقیقاً ۱۵
 *     روز بعد دوباره مجاز به تلاش است — بدون نیاز به هیچ Cron/Scheduled
 *     Worker: واجد شرایط بودنِ تلاش تازه در لحظهٔ درخواست شاگرد محاسبه
 *     می‌شود (`retake_available_at`، مقایسهٔ رشته‌ای datetime سازگار با
 *     فرمت SQLite `datetime('now')`).
 *
 * Endpointها (زیر `/api/v1`):
 *   GET    /final-exam/available                 وضعیت/واجد‌شرایطی شاگرد برای صنف خودش
 *   GET    /final-exams/:id/questions             سؤالات بدون پاسخ (فقط اگر واجد شرایط)
 *   POST   /final-exams/:id/submit                ارسال پاسخ‌ها + نمره‌دهی + ارتقا
 *   GET    /final-exam/my-results                 تاریخچهٔ تلاش‌های شاگرد (خودش/فرزند لینک‌شده)
 *   GET    /final-exam/attempts/:attemptId        مرور سؤال‌به‌سؤال یک تلاش
 *
 *   GET    /admin/final-exams                     آرشیف/لیست همهٔ امتحانات فاینل (هر وضعیتی)
 *   POST   /admin/final-exams                     ایجاد (draft)
 *   PATCH  /admin/final-exams/:id/status          تغییر وضعیت
 *   DELETE /admin/final-exams/:id                  حذف + سؤالات/تلاش‌های وابسته
 *   GET    /admin/final-exams/:id/questions        سؤالات با پاسخ صحیح
 *   POST   /admin/final-exams/:id/questions        افزودن/ویرایش سؤال دستی
 *   DELETE /admin/final-exam-questions/:id
 *   POST   /admin/final-exams/:id/generate-questions   تولید یک‌جا برای همهٔ مضامین با AI
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { gradeEssaysWithAi } from '../lib/essayGrading';
import { generateFinalExamQuestions } from '../lib/finalExam';
import { promoteIfEligible, PROMOTION_EXAM_PASS_PERCENT } from '../lib/progress';
import { COMPETITION_POINTS, awardSafe } from '../lib/competition';
import { logAudit, clientIp } from '../lib/audit';
import { sendPushToUsers } from '../lib/push';
import { hasAdminPermission } from '../lib/permissions';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  // تولید سؤال با AI از GEMINI_API_KEY استفاده می‌کند (نگاه کنید به
  // essayGrading.ts) — همان کلیدی که برای نصاب درسی هم پیکربندی شده.
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
  // پوش نوتیفیکیشن واقعی («امتحان فاینل منتشر شد» + یادآوری فرصت تلاش دوباره).
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
};

/** وقتی مدیر امتحان فاینل را منتشر می‌کند، همهٔ شاگردان فعالِ همان صنف پوش
 * واقعی می‌گیرند — قبلاً هیچ اطلاع‌رسانی‌ای نبود و شاگرد فقط با باز کردن
 * اتفاقی اپ متوجه امتحان تازه می‌شد. Fail-safe: خطا اینجا هرگز انتشار
 * امتحان را شکست نمی‌دهد (فقط لاگ می‌شود). */
async function notifyFinalExamPublished(env: Bindings, examId: string, gradeNumber: number, title: string): Promise<void> {
  try {
    const { results } = await env.DB.prepare(
      "SELECT id FROM users WHERE role = 'student' AND status = 'active' AND current_grade = ?",
    )
      .bind(gradeNumber)
      .all<{ id: string }>();
    const studentIds = results.map((r) => r.id);
    if (studentIds.length === 0) return;
    await sendPushToUsers(
      env,
      studentIds,
      'امتحان فاینل آماده است 📝',
      `«${title}» منتشر شد — هر وقت آماده بودید می‌توانید امتحان بدهید.`,
      { kind: 'final_exam_published', relatedId: examId },
    );
  } catch (err) {
    console.error('[finalExams] notifyFinalExamPublished failed —', err);
  }
}

const finalExams = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}
async function auth(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

const QUESTION_TYPES = new Set(['mcq', 'true_false', 'essay']);
const TRUE_FALSE_OPTIONS = ['صحیح', 'غلط'];
const FINAL_EXAM_RETAKE_DAYS = 15;

/** Super Admin همیشه؛ مدیر زیرمجموعه فقط با دسترسی 'manage_exams'. */
async function requireAdmin(c: any) {
  const me = await auth(c);
  if (!me) return null;
  if (me.role === 'super_admin') return me;
  if (me.role === 'admin' && (await hasAdminPermission(c.env.DB, me.sub, 'manage_exams'))) return me;
  return null;
}

// ═══════════════════════════ سمت شاگرد ═══════════════════════════════════

/** آخرین امتحان فاینلِ منتشرشدهٔ صنفِ شاگرد + آخرین تلاش او (اگر باشد). */
async function loadExamAndLatestAttempt(db: D1Database, grade: number, userId: string) {
  const exam = await db
    .prepare(`SELECT * FROM final_exams WHERE grade_number = ? AND status = 'published' ORDER BY created_at DESC LIMIT 1`)
    .bind(grade)
    .first<any>();
  if (!exam) return { exam: null, attempt: null };
  const attempt = await db
    .prepare(`SELECT * FROM final_exam_attempts WHERE final_exam_id = ? AND user_id = ? ORDER BY attempt_number DESC LIMIT 1`)
    .bind(exam.id, userId)
    .first<any>();
  return { exam, attempt };
}

function computeEligibility(attempt: any) {
  if (!attempt) return { eligible: true, nextAttemptNumber: 1, reason: null as string | null, retakeAvailableAt: null as string | null };
  if (attempt.passed === 1) return { eligible: false, nextAttemptNumber: attempt.attempt_number, reason: 'passed', retakeAvailableAt: null };
  const nowIso = new Date().toISOString().slice(0, 19).replace('T', ' ');
  const ready = attempt.retake_available_at != null && String(attempt.retake_available_at) <= nowIso;
  if (ready) return { eligible: true, nextAttemptNumber: attempt.attempt_number + 1, reason: null, retakeAvailableAt: null };
  return { eligible: false, nextAttemptNumber: attempt.attempt_number + 1, reason: 'cooldown', retakeAvailableAt: attempt.retake_available_at as string | null };
}

finalExams.get('/final-exam/available', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const user = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?').bind(me.sub).first<{ current_grade: number | null }>();
  const grade = user?.current_grade ?? 0;
  const { exam, attempt } = await loadExamAndLatestAttempt(c.env.DB, grade, me.sub);
  if (!exam) return c.json({ exam: null });
  const elig = computeEligibility(attempt);
  return c.json({
    exam: {
      id: exam.id,
      title: exam.title,
      gradeNumber: exam.grade_number,
      questionCount: exam.question_count,
      passThreshold: exam.pass_threshold,
    },
    eligible: elig.eligible,
    nextAttemptNumber: elig.nextAttemptNumber,
    reason: elig.reason,
    retakeAvailableAt: elig.retakeAvailableAt,
    bestScorePercent: attempt?.score_percent ?? null,
  });
});

finalExams.get('/final-exams/:id/questions', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const examId = c.req.param('id');
  const exam = await c.env.DB.prepare(`SELECT * FROM final_exams WHERE id = ? AND status = 'published'`).bind(examId).first<any>();
  if (!exam) return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found', 'ازموینه ونه موندل شوه', 'Examen introuvable'), 404);

  const attempt = await c.env.DB.prepare(
    `SELECT * FROM final_exam_attempts WHERE final_exam_id = ? AND user_id = ? ORDER BY attempt_number DESC LIMIT 1`,
  )
    .bind(examId, me.sub)
    .first<any>();
  const elig = computeEligibility(attempt);
  if (!elig.eligible) {
    return c.json(
      fail(
        'NOT_ELIGIBLE',
        elig.reason === 'passed'
          ? 'شما قبلاً در این امتحان فاینل کامیاب شده‌اید.'
          : `شما ناکام شده‌اید — تلاش بعدی از ${elig.retakeAvailableAt ?? ''} مجاز است.`,
        elig.reason === 'passed' ? 'You have already passed this final exam.' : 'You must wait before retaking this final exam.',
      ),
      409,
    );
  }

  const { results } = await c.env.DB.prepare(
    `SELECT q.id, q.text, q.q_type, q.options, q.subject_id, s.name_fa AS subject_name_fa, q.order_index
     FROM final_exam_questions q JOIN subjects s ON s.id = q.subject_id
     WHERE q.final_exam_id = ? ORDER BY q.order_index`,
  )
    .bind(examId)
    .all<any>();

  return c.json({
    examId,
    title: exam.title,
    attemptNumber: elig.nextAttemptNumber,
    questions: results.map((q) => ({
      id: q.id,
      text: q.text,
      qType: QUESTION_TYPES.has(q.q_type) ? q.q_type : 'mcq',
      options: q.q_type === 'essay' ? [] : JSON.parse(q.options || '[]'),
      subjectId: q.subject_id,
      subjectNameFa: q.subject_name_fa,
    })),
  });
});

finalExams.post('/final-exams/:id/submit', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const examId = c.req.param('id');
  const exam = await c.env.DB.prepare(`SELECT * FROM final_exams WHERE id = ? AND status = 'published'`).bind(examId).first<any>();
  if (!exam) return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found', 'ازموینه ونه موندل شوه', 'Examen introuvable'), 404);

  // بازبینی سمت سرور واجد‌شرایط‌بودن — دفاع در عمق (defense-in-depth)، دقیقاً
  // مثل بررسی مشابه در routes/exams.ts::/exams/:examId/submit؛ کلاینت نباید
  // مبنای تصمیم باشد (ممکن است کهنه/دستکاری‌شده باشد).
  const prevAttempt = await c.env.DB.prepare(
    `SELECT * FROM final_exam_attempts WHERE final_exam_id = ? AND user_id = ? ORDER BY attempt_number DESC LIMIT 1`,
  )
    .bind(examId, me.sub)
    .first<any>();
  const elig = computeEligibility(prevAttempt);
  if (!elig.eligible) {
    return c.json(
      fail(
        'NOT_ELIGIBLE',
        elig.reason === 'passed'
          ? 'شما قبلاً در این امتحان فاینل کامیاب شده‌اید.'
          : `شما ناکام شده‌اید — تلاش بعدی از ${elig.retakeAvailableAt ?? ''} مجاز است.`,
        elig.reason === 'passed' ? 'You have already passed this final exam.' : 'You must wait before retaking this final exam.',
      ),
      409,
    );
  }

  const body = await c.req
    .json<{ answers?: Record<string, number>; textAnswers?: Record<string, string> }>()
    .catch(() => null);
  const answers = body?.answers ?? {};
  const textAnswers = body?.textAnswers ?? {};

  const { results: questions } = await c.env.DB.prepare(
    'SELECT id, text, correct_index, q_type, answer_text, subject_id FROM final_exam_questions WHERE final_exam_id = ?',
  )
    .bind(examId)
    .all<{ id: string; text: string; correct_index: number; q_type: string; answer_text: string | null; subject_id: string }>();
  if (questions.length === 0) {
    return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found', 'ازموینه ونه موندل شوه', 'Examen introuvable'), 404);
  }

  const closed = questions.filter((q) => q.q_type !== 'essay');
  const essays = questions.filter((q) => q.q_type === 'essay');
  let correct = 0;
  for (const q of closed) {
    if (answers[q.id] === q.correct_index) correct++;
  }

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
        if (g.score >= 0.5) correct++;
        essayRecords.push({ questionId: item.id, answer: item.studentAnswer, score: g.score, feedback: g.feedback });
      } else {
        essayRecords.push({ questionId: item.id, answer: item.studentAnswer, score: null, feedback: '' });
      }
    }
  }
  const score = total === 0 ? 0 : Math.round(((points / total) * 100) * 10) / 10;
  const passed = score >= (exam.pass_threshold ?? PROMOTION_EXAM_PASS_PERCENT);
  const attemptNumber = elig.nextAttemptNumber;

  const closedAnswersToStore: Record<string, number> = {};
  for (const q of closed) {
    if (answers[q.id] !== undefined) closedAnswersToStore[q.id] = answers[q.id];
  }

  const attemptId = uid();
  const retakeExpr = passed ? 'NULL' : `datetime('now','+${FINAL_EXAM_RETAKE_DAYS} days')`;
  try {
    await c.env.DB.prepare(
      `INSERT INTO final_exam_attempts
        (id, final_exam_id, user_id, attempt_number, score_percent, correct_count, total_count, passed, essay_answers, answers_json, retake_available_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ${retakeExpr})`,
    )
      .bind(
        attemptId,
        examId,
        me.sub,
        attemptNumber,
        score,
        correct,
        total,
        passed ? 1 : 0,
        essayRecords.length > 0 ? JSON.stringify(essayRecords) : null,
        JSON.stringify(closedAnswersToStore),
      )
      .run();
  } catch (err) {
    if (String(err).includes('UNIQUE constraint failed')) {
      return c.json(
        fail(
          'ALREADY_ATTEMPTED',
          'این تلاش قبلاً ثبت شده است.',
          'This attempt has already been recorded.',
          'دا هڅه دمخه ثبت شوې ده',
          'Cette tentative a déjà été enregistrée.',
        ),
        409,
      );
    }
    throw err;
  }

  let promotion: { promoted: boolean; newGrade: number | null } = { promoted: false, newGrade: null };
  if (passed) {
    promotion = await promoteIfEligible(c.env.DB, me.sub);
    // امتیاز «رقابت مکتب» — پس از کامیابی، تلاش دیگری برای همین امتحان
    // فاینل مجاز نیست (computeEligibility بالا)، پس این هرگز دوبار اجرا
    // نمی‌شود.
    c.executionCtx.waitUntil(awardSafe(c.env.DB, me.sub, COMPETITION_POINTS.finalExamPass, 'final_exam_pass', examId));
  }

  return c.json({
    attemptId,
    scorePercent: score,
    correctCount: correct,
    totalCount: total,
    passed,
    promoted: promotion.promoted,
    newGrade: promotion.newGrade,
    retakeAvailableAt: passed ? null : `+${FINAL_EXAM_RETAKE_DAYS}d`,
  });
});

finalExams.get('/final-exam/my-results', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const requestedId = c.req.query('studentId')?.trim();
  let target = me.sub;
  if (requestedId && requestedId !== me.sub) {
    if (me.role === 'super_admin') {
      target = requestedId;
    } else if (me.role === 'parent') {
      const link = await c.env.DB.prepare(
        "SELECT 1 FROM parent_student_links WHERE parent_user_id=? AND student_user_id=? AND status='approved'",
      )
        .bind(me.sub, requestedId)
        .first();
      if (!link) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
      target = requestedId;
    } else {
      return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
    }
  }

  const { results } = await c.env.DB.prepare(
    `SELECT a.id AS attempt_id, a.final_exam_id, a.attempt_number, a.score_percent, a.correct_count, a.total_count,
            a.passed, a.submitted_at, a.retake_available_at, e.title, e.grade_number
       FROM final_exam_attempts a JOIN final_exams e ON e.id = a.final_exam_id
      WHERE a.user_id = ? ORDER BY a.submitted_at DESC`,
  )
    .bind(target)
    .all<any>();

  return c.json({
    results: results.map((r) => ({
      attemptId: r.attempt_id,
      examId: r.final_exam_id,
      examTitle: r.title,
      gradeNumber: r.grade_number,
      attemptNumber: r.attempt_number,
      scorePercent: r.score_percent,
      correctCount: r.correct_count,
      totalCount: r.total_count,
      passed: r.passed === 1,
      submittedAt: r.submitted_at,
      retakeAvailableAt: r.retake_available_at,
    })),
  });
});

finalExams.get('/final-exam/attempts/:attemptId', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const attemptId = c.req.param('attemptId');
  const attempt = await c.env.DB.prepare(
    `SELECT a.*, e.title, e.grade_number FROM final_exam_attempts a JOIN final_exams e ON e.id = a.final_exam_id WHERE a.id = ?`,
  )
    .bind(attemptId)
    .first<any>();
  if (!attempt) return c.json(fail('NOT_FOUND', 'تلاش یافت نشد', 'Attempt not found'), 404);

  let allowed = me.role === 'super_admin' || attempt.user_id === me.sub;
  if (!allowed && me.role === 'parent') {
    const link = await c.env.DB.prepare(
      "SELECT 1 FROM parent_student_links WHERE parent_user_id=? AND student_user_id=? AND status='approved'",
    )
      .bind(me.sub, attempt.user_id)
      .first();
    allowed = !!link;
  }
  if (!allowed) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);

  const { results: questions } = await c.env.DB.prepare(
    `SELECT q.id, q.text, q.options, q.correct_index, q.q_type, q.answer_text, q.order_index, q.subject_id, s.name_fa AS subject_name_fa
     FROM final_exam_questions q JOIN subjects s ON s.id = q.subject_id
     WHERE q.final_exam_id = ? ORDER BY q.order_index`,
  )
    .bind(attempt.final_exam_id)
    .all<any>();

  const answers: Record<string, number> = attempt.answers_json ? JSON.parse(attempt.answers_json) : {};
  const essayRecords: Array<{ questionId: string; answer: string; score: number | null; feedback: string }> =
    attempt.essay_answers ? JSON.parse(attempt.essay_answers) : [];
  const essayByQ = new Map(essayRecords.map((r) => [r.questionId, r] as const));

  const reviewQuestions = questions.map((q: any) => {
    const qType = QUESTION_TYPES.has(q.q_type) ? q.q_type : 'mcq';
    if (qType === 'essay') {
      const rec = essayByQ.get(q.id);
      return {
        id: q.id,
        text: q.text,
        qType,
        subjectId: q.subject_id,
        subjectNameFa: q.subject_name_fa,
        options: [] as string[],
        correctIndex: -1,
        studentAnswerIndex: -1,
        studentAnswerText: rec?.answer ?? '',
        modelAnswerText: q.answer_text ?? '',
        isCorrect: rec?.score != null ? rec.score >= 0.5 : null,
        essayScore: rec?.score ?? null,
        essayFeedback: rec?.feedback ?? '',
      };
    }
    const options = qType === 'true_false' ? [...TRUE_FALSE_OPTIONS] : JSON.parse(q.options || '[]');
    const studentIdx = answers[q.id] ?? -1;
    return {
      id: q.id,
      text: q.text,
      qType,
      subjectId: q.subject_id,
      subjectNameFa: q.subject_name_fa,
      options,
      correctIndex: q.correct_index,
      studentAnswerIndex: studentIdx,
      studentAnswerText: '',
      modelAnswerText: '',
      isCorrect: studentIdx === q.correct_index,
      essayScore: null,
      essayFeedback: '',
    };
  });

  return c.json({
    attemptId: attempt.id,
    examId: attempt.final_exam_id,
    examTitle: attempt.title,
    gradeNumber: attempt.grade_number,
    attemptNumber: attempt.attempt_number,
    scorePercent: attempt.score_percent,
    correctCount: attempt.correct_count,
    totalCount: attempt.total_count,
    passed: attempt.passed === 1,
    submittedAt: attempt.submitted_at,
    questions: reviewQuestions,
  });
});

// ═══════════════════════════ مدیریت (فقط مدیر) ═══════════════════════════

function adminFinalExamJson(r: any) {
  return {
    id: r.id,
    gradeNumber: r.grade_number,
    academicYear: r.academic_year,
    title: r.title,
    status: r.status,
    passThreshold: r.pass_threshold,
    questionCount: r.question_count,
    createdAt: r.created_at,
  };
}

finalExams.get('/admin/final-exams', async (c) => {
  const me = await requireAdmin(c);
  if (!me) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const grade = c.req.query('grade');
  const { results } = grade
    ? await c.env.DB.prepare('SELECT * FROM final_exams WHERE grade_number = ? ORDER BY created_at DESC').bind(Number(grade)).all<any>()
    : await c.env.DB.prepare('SELECT * FROM final_exams ORDER BY grade_number, created_at DESC').all<any>();
  return c.json({ finalExams: results.map(adminFinalExamJson) });
});

finalExams.post('/admin/final-exams', async (c) => {
  const me = await requireAdmin(c);
  if (!me) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const b = await c.req.json<{ gradeNumber?: number; academicYear?: string; title?: string }>().catch(() => null);
  const gradeNumber = Number(b?.gradeNumber ?? 0);
  const title = String(b?.title ?? '').trim();
  if (!gradeNumber || !title) {
    return c.json(fail('BAD_REQUEST', 'صنف و عنوان لازم است', 'Grade and title are required'), 400);
  }
  const id = uid();
  await c.env.DB.prepare(
    `INSERT INTO final_exams (id, grade_number, academic_year, title, status, question_count) VALUES (?, ?, ?, ?, 'draft', 0)`,
  )
    .bind(id, gradeNumber, String(b?.academicYear ?? '').trim(), title)
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM final_exams WHERE id = ?').bind(id).first<any>();
  return c.json({ finalExam: adminFinalExamJson(row) }, 201);
});

finalExams.patch('/admin/final-exams/:id/status', async (c) => {
  const me = await requireAdmin(c);
  if (!me) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  const status = ['draft', 'published', 'closed'].includes(String(b?.status)) ? String(b!.status) : 'draft';

  const before = await c.env.DB.prepare('SELECT status, grade_number, title FROM final_exams WHERE id = ?')
    .bind(id)
    .first<{ status: string; grade_number: number; title: string }>();
  await c.env.DB.prepare('UPDATE final_exams SET status = ? WHERE id = ?').bind(status, id).run();

  // Push فقط وقتی امتحان *تازه* منتشر می‌شود (draft/closed → published) —
  // نه در هر بار PATCH، وگرنه هر تغییر وضعیت دیگر هم دوباره به همه Push می‌زد.
  if (before && before.status !== 'published' && status === 'published') {
    c.executionCtx.waitUntil(notifyFinalExamPublished(c.env, id, before.grade_number, before.title));
  }
  return c.json({ success: true });
});

finalExams.delete('/admin/final-exams/:id', async (c) => {
  const me = await requireAdmin(c);
  if (!me) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const before = await c.env.DB.prepare('SELECT title, grade_number FROM final_exams WHERE id = ?').bind(id).first<any>();
  await c.env.DB.prepare('DELETE FROM final_exam_attempts WHERE final_exam_id = ?').bind(id).run();
  await c.env.DB.prepare('DELETE FROM final_exam_questions WHERE final_exam_id = ?').bind(id).run();
  await c.env.DB.prepare('DELETE FROM final_exams WHERE id = ?').bind(id).run();
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: me.sub,
      actorRole: me.role,
      actionType: 'final_exam_delete',
      targetTable: 'final_exams',
      targetId: id,
      beforeValue: before,
      ipAddress: clientIp(c),
      priority: 'high',
    }),
  );
  return c.json({ success: true });
});

finalExams.get('/admin/final-exams/:id/questions', async (c) => {
  const me = await requireAdmin(c);
  if (!me) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const { results } = await c.env.DB.prepare(
    `SELECT q.*, s.name_fa AS subject_name_fa FROM final_exam_questions q JOIN subjects s ON s.id = q.subject_id
     WHERE q.final_exam_id = ? ORDER BY q.order_index`,
  )
    .bind(c.req.param('id'))
    .all<any>();
  return c.json({
    questions: results.map((q) => ({
      id: q.id,
      finalExamId: q.final_exam_id,
      subjectId: q.subject_id,
      subjectNameFa: q.subject_name_fa,
      qType: QUESTION_TYPES.has(q.q_type) ? q.q_type : 'mcq',
      text: q.text,
      options: JSON.parse(q.options || '[]'),
      correctIndex: q.correct_index,
      answerText: q.answer_text ?? '',
      orderIndex: q.order_index,
    })),
  });
});

finalExams.post('/admin/final-exams/:id/questions', async (c) => {
  const me = await requireAdmin(c);
  if (!me) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const finalExamId = c.req.param('id');
  const exam = await c.env.DB.prepare('SELECT id FROM final_exams WHERE id = ?').bind(finalExamId).first();
  if (!exam) return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found'), 404);

  const b = await c.req
    .json<{
      id?: string;
      subjectId?: string;
      qType?: string;
      text?: string;
      options?: string[];
      correctIndex?: number;
      answerText?: string;
      orderIndex?: number;
    }>()
    .catch(() => null);
  const subjectId = String(b?.subjectId ?? '').trim();
  const text = String(b?.text ?? '').trim();
  const qType = QUESTION_TYPES.has(String(b?.qType)) ? String(b!.qType) : 'mcq';
  let options = Array.isArray(b?.options) ? b!.options!.map((o) => String(o)) : [];
  let correctIndex = Number(b?.correctIndex ?? -1);
  const answerText = String(b?.answerText ?? '').trim();

  if (!subjectId || !text) return c.json(fail('BAD_REQUEST', 'مضمون و متن سؤال لازم است', 'Subject and question text are required'), 400);
  if (qType === 'essay') {
    options = [];
    correctIndex = -1;
  } else if (qType === 'true_false') {
    options = [...TRUE_FALSE_OPTIONS];
    if (correctIndex !== 0 && correctIndex !== 1) {
      return c.json(fail('BAD_REQUEST', 'پاسخ صحیح صحیح/غلط باید مشخص شود', 'Invalid true/false answer'), 400);
    }
  } else if (options.length < 2 || correctIndex < 0 || correctIndex >= options.length) {
    return c.json(fail('BAD_REQUEST', 'حداقل ۲ گزینه و پاسخ صحیح معتبر لازم است', 'At least 2 options and a valid correct answer are required'), 400);
  }

  const id = b?.id && String(b.id).trim().length > 0 ? String(b.id).trim() : uid();
  const existing = await c.env.DB.prepare('SELECT id FROM final_exam_questions WHERE id = ?').bind(id).first();
  let orderIndex = Number(b?.orderIndex ?? 0);
  if (!existing && !orderIndex) {
    const countRow = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM final_exam_questions WHERE final_exam_id = ?')
      .bind(finalExamId)
      .first<{ n: number }>();
    orderIndex = (countRow?.n ?? 0) + 1;
  }
  if (existing) {
    await c.env.DB.prepare(
      'UPDATE final_exam_questions SET subject_id=?, q_type=?, text=?, options=?, correct_index=?, answer_text=?, order_index=? WHERE id=?',
    )
      .bind(subjectId, qType, text, JSON.stringify(options), correctIndex, answerText || null, orderIndex, id)
      .run();
  } else {
    await c.env.DB.prepare(
      'INSERT INTO final_exam_questions (id, final_exam_id, subject_id, q_type, text, options, correct_index, answer_text, order_index) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
    )
      .bind(id, finalExamId, subjectId, qType, text, JSON.stringify(options), correctIndex, answerText || null, orderIndex)
      .run();
    await c.env.DB.prepare('UPDATE final_exams SET question_count = question_count + 1 WHERE id = ?').bind(finalExamId).run();
  }
  return c.json({ question: { id, finalExamId, subjectId, qType, text, options, correctIndex, answerText, orderIndex } }, existing ? 200 : 201);
});

finalExams.delete('/admin/final-exam-questions/:id', async (c) => {
  const me = await requireAdmin(c);
  if (!me) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  const id = c.req.param('id');
  const row = await c.env.DB.prepare('SELECT final_exam_id FROM final_exam_questions WHERE id = ?').bind(id).first<{ final_exam_id: string }>();
  await c.env.DB.prepare('DELETE FROM final_exam_questions WHERE id = ?').bind(id).run();
  if (row) await c.env.DB.prepare('UPDATE final_exams SET question_count = MAX(0, question_count - 1) WHERE id = ?').bind(row.final_exam_id).run();
  return c.json({ success: true });
});

// ─────────── تولید یک‌جا برای همهٔ مضامین صنف با هوش مصنوعی ────────────────
// حداقل ۳ سؤال از هر مضمون (FINAL_EXAM_MIN_PER_SUBJECT) — اگر صنف مثلاً ۱۰
// مضمون داشته باشد، در مجموع نزدیک به ۳۰ سؤال ساخته می‌شود، دقیقاً طبق
// درخواست صاحب پروژه. مضمونی که AI برایش سؤال نساخت (خطای موقت) در پاسخ
// گزارش می‌شود تا مدیر بتواند برایش دستی اضافه کند — کل درخواست شکست نمی‌خورد.
finalExams.post('/admin/final-exams/:id/generate-questions', async (c) => {
  const me = await requireAdmin(c);
  if (!me) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden'), 403);
  if (!c.env.GEMINI_API_KEY) {
    return c.json(fail('AI_NOT_CONFIGURED', 'موتور هوش مصنوعی سرور پیکربندی نشده است', 'AI provider not configured'), 503);
  }
  const finalExamId = c.req.param('id');
  const exam = await c.env.DB.prepare('SELECT grade_number FROM final_exams WHERE id = ?').bind(finalExamId).first<{ grade_number: number }>();
  if (!exam) return c.json(fail('NOT_FOUND', 'امتحان یافت نشد', 'Exam not found'), 404);

  const b = await c.req.json<{ perSubjectCount?: number }>().catch(() => null);
  const perSubjectCount = Math.max(3, Math.min(10, Math.floor(Number(b?.perSubjectCount ?? 3)) || 3));

  const { results: subjects } = await c.env.DB.prepare(
    `SELECT s.id, s.name_fa FROM subjects s
     WHERE EXISTS (SELECT 1 FROM chapters ch WHERE ch.subject_id = s.id AND ch.grade_number = ? AND ch.status = 'published')
     ORDER BY s.order_index`,
  )
    .bind(exam.grade_number)
    .all<{ id: string; name_fa: string }>();
  if (subjects.length === 0) {
    return c.json(fail('BAD_REQUEST', 'برای این صنف هیچ مضمونی با محتوا یافت نشد', 'No subjects with content found for this grade'), 400);
  }

  const generated = await generateFinalExamQuestions(c.env, {
    gradeNumber: exam.grade_number,
    subjects: subjects.map((s) => ({ id: s.id, nameFa: s.name_fa })),
    perSubjectCount,
  });

  const countRow = await c.env.DB.prepare('SELECT COUNT(*) AS n FROM final_exam_questions WHERE final_exam_id = ?')
    .bind(finalExamId)
    .first<{ n: number }>();
  let orderIndex = countRow?.n ?? 0;
  const statements: D1PreparedStatement[] = [];
  const perSubjectSaved: Array<{ subjectId: string; subjectNameFa: string; count: number }> = [];
  const failedSubjects: string[] = [];

  for (const g of generated) {
    if (g.questions.length === 0) {
      failedSubjects.push(subjects.find((s) => s.id === g.subjectId)?.name_fa ?? g.subjectId);
      continue;
    }
    for (const q of g.questions) {
      orderIndex += 1;
      statements.push(
        c.env.DB.prepare(
          'INSERT INTO final_exam_questions (id, final_exam_id, subject_id, q_type, text, options, correct_index, answer_text, order_index) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        ).bind(uid(), finalExamId, g.subjectId, q.q_type, q.text, JSON.stringify(q.options), q.correct_index, q.answer_text, orderIndex),
      );
    }
    perSubjectSaved.push({
      subjectId: g.subjectId,
      subjectNameFa: subjects.find((s) => s.id === g.subjectId)?.name_fa ?? '',
      count: g.questions.length,
    });
  }

  if (statements.length > 0) {
    await c.env.DB.batch(statements);
    await c.env.DB.prepare('UPDATE final_exams SET question_count = question_count + ? WHERE id = ?').bind(statements.length, finalExamId).run();
  }

  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: me.sub,
      actorRole: me.role,
      actionType: 'ai_invocation',
      targetTable: 'final_exam_questions',
      targetId: finalExamId,
      ipAddress: clientIp(c),
      detail: { purpose: 'final_exam_generation', perSubjectCount, saved: statements.length, failedSubjects },
    }),
  );

  return c.json({ savedCount: statements.length, perSubject: perSubjectSaved, failedSubjects }, 201);
});

export default finalExams;
