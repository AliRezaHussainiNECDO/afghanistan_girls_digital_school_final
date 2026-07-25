/**
 * lib/chapterQuiz.ts — «آزمون فصل» خودکار با هوش مصنوعی (بخش جدید طبق درخواست
 * صاحب پروژه، پیوستهٔ migration 0041).
 *
 * منطق: وقتی شاگرد آخرین درسِ یک فصل را می‌بیند (`chapterJustCompleted` در
 * `lib/progress.ts::recordLessonView`)، اینجا صدا زده می‌شود تا — اگر قبلاً
 * برای همین فصل ساخته نشده — یک آزمون با حداقل ۱۲ سؤال ترکیبی (صحیح/غلط +
 * چهارگزینه‌ای + تشریحی) بسازد. این آزمون **یک‌بار برای کل فصل** ساخته
 * می‌شود (نه برای هر شاگرد جداگانه) تا هزینهٔ AI تکراری نشود؛ همهٔ شاگردانی
 * که به این فصل می‌رسند همان سؤالات را می‌بینند، ولی هرکدام تلاش/نمرهٔ
 * جداگانهٔ خودشان را دارند (`chapter_quiz_attempts`، یک‌بار قابل ارسال).
 *
 * Fail-safe (هماهنگ با فلسفهٔ بقیهٔ فایل — نگاه کنید به کامنت‌های
 * `getLessonLockList` در progress.ts): اگر AI پیکربندی نشده یا خطا بدهد،
 * این تابع `null` برمی‌گرداند و **هیچ ردیفی در `chapter_quizzes` ساخته
 * نمی‌شود** — یعنی `getChapterList` (progress.ts) به‌طور خودکار به رفتار
 * قدیمی (باز شدن فصل بعدی صرفاً با دیدن همهٔ درس‌ها) بازمی‌گردد. هیچ
 * شاگردی هرگز به‌خاطر قطعی سرویس AI برای همیشه پشت قفل نمی‌ماند.
 */
import { callAiJsonArrayLenient, gradeEssaysWithAi, type EssayAiBindings } from './essayGrading';

export type ChapterQuizBindings = EssayAiBindings & { DB: D1Database };

const uid = () => crypto.randomUUID();
const QUESTION_TYPES = new Set(['mcq', 'true_false', 'essay']);
const TRUE_FALSE_OPTIONS = ['صحیح', 'غلط'];

/** حداقل تعداد سؤال طبق درخواست صریح صاحب پروژه. ترکیب پیش‌فرض: ۵ صحیح/غلط
 * + ۴ چهارگزینه‌ای + ۳ تشریحی = ۱۲ — لحن آزمون باید تشویقی باشد، نه سخت‌گیرانه. */
export const CHAPTER_QUIZ_MIN_QUESTIONS = 12;
export const CHAPTER_QUIZ_PASS_PERCENT_DEFAULT = 40;

export type ChapterQuizQuestionRow = {
  id: string;
  quiz_id: string;
  q_type: string;
  text: string;
  options: string;
  correct_index: number;
  answer_text: string | null;
  order_index: number;
};

/** اگر آزمون این فصل از قبل ساخته شده، همان id را برمی‌گرداند؛ در غیر این
 * صورت با AI می‌سازد. `null` یعنی نه از قبل وجود داشت و نه ساخته شد (AI در
 * دسترس نبود/خطا) — فراخوان باید این حالت را بی‌صدا نادیده بگیرد. */
export async function ensureChapterQuiz(env: ChapterQuizBindings, chapterId: string): Promise<{ id: string } | null> {
  const existing = await env.DB.prepare('SELECT id FROM chapter_quizzes WHERE chapter_id = ?').bind(chapterId).first<{ id: string }>();
  if (existing) return { id: existing.id };
  if (!env.GEMINI_API_KEY) return null;

  const chapter = await env.DB.prepare(
    `SELECT ch.title_fa, ch.grade_number, s.name_fa AS subject_name_fa
     FROM chapters ch JOIN subjects s ON s.id = ch.subject_id
     WHERE ch.id = ?`,
  )
    .bind(chapterId)
    .first<{ title_fa: string; grade_number: number; subject_name_fa: string }>();
  if (!chapter) return null;

  const trueFalseCount = 5;
  const mcqCount = 4;
  const essayCount = 3;

  let parsed: any[];
  try {
    parsed = await callAiJsonArrayLenient(
      env,
      'تو یک معلم مهربان و باتجربهٔ مکتب هستی که برای شاگردان دختر افغانستان «آزمون کوتاه پایان فصل» می‌سازی. ' +
        'هدف این آزمون سنجش سخت‌گیرانه نیست — هدف این است که شاگرد با اطمینان و حس مثبت مرور کند چقدر از فصل را یاد گرفته. ' +
        'سؤالات باید ساده، واضح و کاملاً منطبق با سطح صنف باشند. فقط JSON خالص برگردان — بدون هیچ متن اضافه.',
      `فصل «${chapter.title_fa}» از مضمون «${chapter.subject_name_fa}» صنف ${chapter.grade_number}.\n` +
        `${trueFalseCount} سؤال صحیح/غلط (type="true_false"، بدون options، correctIndex: 0 یعنی «صحیح»، 1 یعنی «غلط»)\n` +
        `${mcqCount} سؤال چهارگزینه‌ای (type="mcq"، دقیقاً ۴ گزینه، correctIndex از 0 تا 3)\n` +
        `${essayCount} سؤال تشریحی کوتاه (type="essay"، بدون options، فیلد answer = پاسخ نمونهٔ کوتاه برای کلید نمره‌دهی)\n` +
        `خروجی: آرایهٔ JSON دقیقاً به شکل [{"type":"true_false","text":"...","correctIndex":0},{"type":"mcq","text":"...","options":["..","..","..",".."],"correctIndex":2},{"type":"essay","text":"...","answer":"..."}]`,
      4000,
    );
  } catch {
    return null; // خطای شبکه/AI — بی‌صدا fail-safe (شرح بالای فایل)
  }
  if (!Array.isArray(parsed) || parsed.length === 0) return null;

  const rows: Array<{ q_type: string; text: string; options: string[]; correct_index: number; answer_text: string | null }> = [];
  for (const item of parsed) {
    const qType = QUESTION_TYPES.has(String(item?.type)) ? String(item.type) : null;
    const text = String(item?.text ?? '').trim();
    if (!qType || !text) continue;
    if (qType === 'mcq') {
      const options = Array.isArray(item?.options) ? item.options.map((o: unknown) => String(o)) : [];
      const correctIndex = Number(item?.correctIndex ?? -1);
      if (options.length < 2 || correctIndex < 0 || correctIndex >= options.length) continue;
      rows.push({ q_type: 'mcq', text, options, correct_index: correctIndex, answer_text: null });
    } else if (qType === 'true_false') {
      const correctIndex = Number(item?.correctIndex) === 1 ? 1 : 0;
      rows.push({ q_type: 'true_false', text, options: [...TRUE_FALSE_OPTIONS], correct_index: correctIndex, answer_text: null });
    } else {
      rows.push({ q_type: 'essay', text, options: [], correct_index: -1, answer_text: String(item?.answer ?? '').trim() || null });
    }
  }

  // اگر خیلی کم (کمتر از نیمی از حداقل درخواستی) ساخته شد، بهتر است اصلاً
  // آزمون ناقص منتشر نشود — fail-safe: fallback به رفتار قدیمی (دیدن دروس).
  if (rows.length < Math.ceil(CHAPTER_QUIZ_MIN_QUESTIONS / 2)) return null;

  const quizId = uid();
  await env.DB.prepare(
    `INSERT INTO chapter_quizzes (id, chapter_id, status, pass_threshold, question_count)
     VALUES (?, ?, 'published', ?, ?)`,
  )
    .bind(quizId, chapterId, CHAPTER_QUIZ_PASS_PERCENT_DEFAULT, rows.length)
    .run();

  const qStmt = env.DB.prepare(
    `INSERT INTO chapter_quiz_questions (id, quiz_id, q_type, text, options, correct_index, answer_text, order_index)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
  );
  await env.DB.batch(
    rows.map((r, i) => qStmt.bind(uid(), quizId, r.q_type, r.text, JSON.stringify(r.options), r.correct_index, r.answer_text, i + 1)),
  );

  return { id: quizId };
}

/** نمره‌دهی پاسخ‌های ارسالی یک آزمون فصل — همان الگوی دقیق
 * routes/exams.ts::/exams/:examId/submit (بسته‌ها فوری، تشریحی با AI). */
export async function gradeChapterQuizSubmission(
  env: ChapterQuizBindings,
  quizId: string,
  answers: Record<string, number>,
  textAnswers: Record<string, string>,
): Promise<{
  score: number;
  correct: number;
  total: number;
  essayRecords: Array<{ questionId: string; answer: string; score: number | null; feedback: string }>;
  closedAnswersToStore: Record<string, number>;
}> {
  const { results } = await env.DB.prepare(
    'SELECT id, text, correct_index, q_type, answer_text FROM chapter_quiz_questions WHERE quiz_id = ?',
  )
    .bind(quizId)
    .all<{ id: string; text: string; correct_index: number; q_type: string; answer_text: string | null }>();

  const closed = results.filter((q) => q.q_type !== 'essay');
  const essays = results.filter((q) => q.q_type === 'essay');
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
    const graded = await gradeEssaysWithAi(env, items.filter((i) => i.studentAnswer.length > 0));
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

  const closedAnswersToStore: Record<string, number> = {};
  for (const q of closed) {
    if (answers[q.id] !== undefined) closedAnswersToStore[q.id] = answers[q.id];
  }

  const score = total === 0 ? 0 : (points / total) * 100;
  return { score: Math.round(score * 10) / 10, correct, total, essayRecords, closedAnswersToStore };
}
