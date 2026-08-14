/**
 * routes/chapterQuizzes.ts — «آزمون فصل» خودکار با هوش مصنوعی (migration 0041،
 * lib/chapterQuiz.ts). طبق درخواست صاحب پروژه:
 *   - وقتی شاگرد همهٔ درس‌های یک فصل را می‌بیند، سیستم خودکار (پس‌زمینه،
 *     `routes/curriculum.ts::/lessons/:lessonId/view`) یک آزمون حداقل ۱۲
 *     سؤالیِ ترکیبی (صحیح/غلط + چهارگزینه‌ای + تشریحی) با AI می‌سازد.
 *   - این آزمون سخت‌گیرانه نیست (آستانهٔ قبولی پیش‌فرض ۴۰٪) و صرفِ ارسال آن
 *     (یک‌بار، مثل امتحانات رسمی) فصل بعدی را باز می‌کند
 *     (lib/progress.ts::getChapterList).
 *   - نمرات در پروندهٔ شاگرد قابل مرور است (`GET` بعد از ارسال، فورم
 *     سؤال/پاسخ/پاسخ‌درست را برمی‌گرداند).
 *
 * Endpointها (زیر `/api/v1`):
 *   GET  /chapters/:chapterId/quiz          فورم آزمون (پیش/پس از ارسال)
 *   POST /chapters/:chapterId/quiz/submit   ارسال پاسخ‌ها — یک‌بار مجاز
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { gradeChapterQuizSubmission, type ChapterQuizBindings } from '../lib/chapterQuiz';
import { COMPETITION_POINTS, awardSafe } from '../lib/competition';

type Bindings = ChapterQuizBindings & { JWT_SECRET: string };
const chapterQuizzes = new Hono<{ Bindings: Bindings }>();
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

// ─────────────────────── فورم آزمون فصل (پیش/پس از ارسال) ───────────────────

chapterQuizzes.get('/chapters/:chapterId/quiz', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const chapterId = c.req.param('chapterId');

  const chapter = await c.env.DB.prepare(
    `SELECT ch.title_fa, cq.id AS quiz_id, cq.pass_threshold
     FROM chapters ch LEFT JOIN chapter_quizzes cq ON cq.chapter_id = ch.id AND cq.status = 'published'
     WHERE ch.id = ?`,
  )
    .bind(chapterId)
    .first<{ title_fa: string; quiz_id: string | null; pass_threshold: number | null }>();
  if (!chapter) return c.json(fail('NOT_FOUND', 'فصل یافت نشد', 'Chapter not found', 'فصل ونه موندل شو', 'Chapitre introuvable'), 404);
  if (!chapter.quiz_id) {
    // هنوز آزمونی برای این فصل ساخته نشده (یا شاگرد هنوز همهٔ درس‌ها را
    // ندیده، یا AI موقتاً در دسترس نبوده — fail-safe در lib/chapterQuiz.ts).
    return c.json(
      fail(
        'QUIZ_NOT_READY',
        'آزمون این فصل هنوز آماده نشده — بعد از دیدن تمام درس‌های فصل، این آزمون به‌صورت خودکار آماده می‌شود.',
        'This chapter quiz is not ready yet.',
        'د دې فصل ازموینه لا تر اوسه چمتو نه ده',
        "Le quiz de ce chapitre n'est pas encore prêt.",
      ),
      404,
    );
  }

  const attempt = await c.env.DB.prepare('SELECT * FROM chapter_quiz_attempts WHERE quiz_id = ? AND user_id = ?')
    .bind(chapter.quiz_id, me.sub)
    .first<any>();

  const { results: questions } = await c.env.DB.prepare(
    'SELECT id, text, options, correct_index, q_type, answer_text, order_index FROM chapter_quiz_questions WHERE quiz_id = ? ORDER BY order_index',
  )
    .bind(chapter.quiz_id)
    .all<any>();

  if (!attempt) {
    // پیش از ارسال — بدون پاسخ صحیح (دقیقاً هم‌الگو با /exams/:examId/questions).
    return c.json({
      chapterId,
      quizId: chapter.quiz_id,
      title: `آزمون فصل: ${chapter.title_fa}`,
      passThreshold: chapter.pass_threshold ?? 40,
      submitted: false,
      questions: questions.map((q) => ({
        id: q.id,
        text: q.text,
        qType: QUESTION_TYPES.has(q.q_type) ? q.q_type : 'mcq',
        options: q.q_type === 'essay' ? [] : JSON.parse(q.options || '[]'),
      })),
    });
  }

  // پس از ارسال — فورم مرور کامل (سؤال/پاسخِ شاگرد/پاسخ درست/نمره).
  const answers: Record<string, number> = attempt.answers_json ? JSON.parse(attempt.answers_json) : {};
  const essayRecords: Array<{ questionId: string; answer: string; score: number | null; feedback: string }> =
    attempt.essay_answers ? JSON.parse(attempt.essay_answers) : [];
  const essayByQ = new Map(essayRecords.map((r) => [r.questionId, r] as const));

  return c.json({
    chapterId,
    quizId: chapter.quiz_id,
    title: `آزمون فصل: ${chapter.title_fa}`,
    passThreshold: chapter.pass_threshold ?? 40,
    submitted: true,
    scorePercent: attempt.score_percent,
    correctCount: attempt.correct_count,
    totalCount: attempt.total_count,
    passed: attempt.passed === 1,
    submittedAt: attempt.submitted_at,
    questions: questions.map((q: any) => {
      const qType = QUESTION_TYPES.has(q.q_type) ? q.q_type : 'mcq';
      if (qType === 'essay') {
        const rec = essayByQ.get(q.id);
        return {
          id: q.id,
          text: q.text,
          qType,
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
        options,
        correctIndex: q.correct_index,
        studentAnswerIndex: studentIdx,
        studentAnswerText: '',
        modelAnswerText: '',
        isCorrect: studentIdx === q.correct_index,
        essayScore: null,
        essayFeedback: '',
      };
    }),
  });
});

// ────────────────────────── ارسال پاسخ‌ها (یک‌بار مجاز) ──────────────────────

chapterQuizzes.post('/chapters/:chapterId/quiz/submit', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const chapterId = c.req.param('chapterId');

  const quiz = await c.env.DB.prepare(
    `SELECT id, chapter_id, pass_threshold FROM chapter_quizzes WHERE chapter_id = ? AND status = 'published'`,
  )
    .bind(chapterId)
    .first<{ id: string; chapter_id: string; pass_threshold: number }>();
  if (!quiz) return c.json(fail('NOT_FOUND', 'آزمون یافت نشد', 'Quiz not found', 'ازموینه ونه موندل شوه', 'Quiz introuvable'), 404);

  const already = await c.env.DB.prepare('SELECT id FROM chapter_quiz_attempts WHERE quiz_id = ? AND user_id = ?')
    .bind(quiz.id, me.sub)
    .first();
  if (already) {
    return c.json(
      fail(
        'ALREADY_ATTEMPTED',
        'شما قبلاً در این آزمون فصل شرکت کرده‌اید — هر آزمون فقط یک‌بار قابل دادن است.',
        'You have already taken this chapter quiz.',
        'تاسو دمخه پدې ازموینه کې برخه اخیستې ده',
        'Vous avez déjà passé ce quiz.',
      ),
      409,
    );
  }

  const body = await c.req
    .json<{ answers?: Record<string, number>; textAnswers?: Record<string, string> }>()
    .catch(() => null);
  const { score, correct, total, essayRecords, closedAnswersToStore } = await gradeChapterQuizSubmission(
    c.env,
    quiz.id,
    body?.answers ?? {},
    body?.textAnswers ?? {},
  );
  const passed = score >= (quiz.pass_threshold ?? 40);

  try {
    await c.env.DB.prepare(
      `INSERT INTO chapter_quiz_attempts
        (id, quiz_id, chapter_id, user_id, score_percent, correct_count, total_count, passed, essay_answers, answers_json)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        uid(),
        quiz.id,
        chapterId,
        me.sub,
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
          'شما قبلاً در این آزمون فصل شرکت کرده‌اید — هر آزمون فقط یک‌بار قابل دادن است.',
          'You have already taken this chapter quiz.',
          'تاسو دمخه پدې ازموینه کې برخه اخیستې ده',
          'Vous avez déjà passé ce quiz.',
        ),
        409,
      );
    }
    throw err;
  }

  // طبق طراحی عمدی (نه سخت‌گیرانه): صرفِ ارسال این آزمون فصل بعدی را باز
  // می‌کند — نگاه کنید به lib/progress.ts::getChapterList (شرط hasQuiz ?
  // quizSubmitted : ...). اینجا کاری اضافه لازم نیست؛ همان لحظه که این
  // ردیف در chapter_quiz_attempts ثبت شد، فراخوانی بعدیِ فهرست فصل‌ها
  // خودکار فصل بعدی را unlocked نشان می‌دهد.

  // امتیاز «رقابت مکتب» برای کامیابی در آزمون فصل — هر آزمون فصل هم فقط
  // یک‌بار قابل دادن است (بررسی بالای همین Endpoint). اگر این آزمون در بازهٔ
  // کوتاهی بعد از تکمیل فصل (یعنی «بلافاصله» طبق سند اقتصاد امتیاز) داده
  // شود، ۱۰٪ پاداش اضافه هم می‌گیرد.
  if (passed) {
    c.executionCtx.waitUntil(awardSafe(c.env.DB, me.sub, COMPETITION_POINTS.chapterQuizPass, 'chapter_quiz_pass', quiz.id));
    c.executionCtx.waitUntil(
      (async () => {
        try {
          const completedRow = await c.env.DB.prepare(
            "SELECT created_at FROM student_points_ledger WHERE student_id = ? AND reason = 'chapter_complete' AND ref_id = ? ORDER BY created_at DESC LIMIT 1",
          )
            .bind(me.sub, chapterId)
            .first<{ created_at: string }>();
          if (!completedRow) return;
          const elapsedMinutes = (Date.now() - new Date(`${completedRow.created_at.replace(' ', 'T')}Z`).getTime()) / 60000;
          if (elapsedMinutes >= 0 && elapsedMinutes <= COMPETITION_POINTS.chapterQuizEarlyWindowMinutes) {
            const bonus = Math.round((COMPETITION_POINTS.chapterQuizPass * COMPETITION_POINTS.chapterQuizEarlyBonusPercent) / 100);
            await awardSafe(c.env.DB, me.sub, bonus, 'chapter_quiz_early_bonus', quiz.id);
          }
        } catch (err) {
          console.error('[chapterQuizzes.submit] early bonus fail-safe —', err);
        }
      })(),
    );
  }

  return c.json({ scorePercent: score, correctCount: correct, totalCount: total, passed });
});

export default chapterQuizzes;
