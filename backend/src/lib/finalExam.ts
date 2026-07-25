/**
 * lib/finalExam.ts — امتحان فاینل چندمضمونه (migration 0041) با هوش مصنوعی.
 *
 * برخلاف امتحان «نهاییِ» قدیمی (`exams.type='final'` که تک‌مضمونه بود)، این
 * یک امتحان واحد برای کل صنف است: حداقل ۳ سؤال از هر مضمون، در مجموع حدود
 * ۳۰ سؤال. مدیر می‌تواند سؤالات را دستی بسازد یا با این تابع یک‌جا برای
 * همهٔ مضامین صنف با AI تولید کند (مدیر پیش از انتشار پیش‌نمایش می‌بیند).
 */
import { callAiJsonArrayLenient, type EssayAiBindings } from './essayGrading';

export type FinalExamAiBindings = EssayAiBindings;

export const FINAL_EXAM_MIN_PER_SUBJECT = 3;

export type GeneratedFinalExamQuestion = {
  q_type: 'mcq' | 'true_false' | 'essay';
  text: string;
  options: string[];
  correct_index: number;
  answer_text: string | null;
};

const QUESTION_TYPES = new Set(['mcq', 'true_false', 'essay']);
const TRUE_FALSE_OPTIONS = ['صحیح', 'غلط'];

function normalize(parsed: any[]): GeneratedFinalExamQuestion[] {
  const rows: GeneratedFinalExamQuestion[] = [];
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
  return rows;
}

/** برای یک مضمون مشخص، سؤالات امتحان فاینل تولید می‌کند (پیش‌فرض ۳: ۱
 * صحیح/غلط + ۱ چهارگزینه‌ای + ۱ تشریحی، تا کل صنف را با تعادل بین انواع
 * سؤال پوشش دهد). در نبود AI یا خطا، آرایهٔ خالی برمی‌گرداند — فراخوان
 * (روت مدیر) این را به‌عنوان «تولید ناموفق برای این مضمون» گزارش می‌کند،
 * نه اینکه کل درخواست را خراب کند. */
export async function generateFinalExamQuestionsForSubject(
  env: FinalExamAiBindings,
  opts: { gradeNumber: number; subjectNameFa: string; count?: number },
): Promise<GeneratedFinalExamQuestion[]> {
  if (!env.GEMINI_API_KEY) return [];
  const count = Math.max(opts.count ?? FINAL_EXAM_MIN_PER_SUBJECT, FINAL_EXAM_MIN_PER_SUBJECT);
  const trueFalseCount = Math.max(1, Math.round(count / 3));
  const mcqCount = Math.max(1, Math.round(count / 3));
  const essayCount = Math.max(1, count - trueFalseCount - mcqCount);

  try {
    const parsed = await callAiJsonArrayLenient(
      env,
      'تو یک معلم باتجربهٔ نصاب معارف افغانستان هستی و برای امتحان فاینل (نهاییِ سال) شاگردان دختر سؤال می‌سازی. ' +
        'سؤالات باید کل مضمونِ صنف را بسنجند، منصفانه و بدون ابهام باشند. فقط JSON خالص برگردان.',
      `مضمون «${opts.subjectNameFa}» صنف ${opts.gradeNumber} — امتحان فاینل پایان سال.\n` +
        `${trueFalseCount} سؤال صحیح/غلط (type="true_false"، correctIndex: 0=«صحیح»، 1=«غلط»)\n` +
        `${mcqCount} سؤال چهارگزینه‌ای (type="mcq"، دقیقاً ۴ گزینه، correctIndex از 0 تا 3)\n` +
        `${essayCount} سؤال تشریحی (type="essay"، فیلد answer = پاسخ نمونه برای کلید نمره‌دهی)\n` +
        `سؤالات باید کل نصاب سال این مضمون در این صنف را پوشش دهند، نه فقط یک فصل.\n` +
        `خروجی: آرایهٔ JSON دقیقاً به شکل [{"type":"mcq","text":"...","options":["..","..","..",".."],"correctIndex":0}]`,
      Math.min(8000, 900 + count * 260),
    );
    if (!Array.isArray(parsed)) return [];
    return normalize(parsed);
  } catch {
    return [];
  }
}

/** تولید موازی برای همهٔ مضامین یک صنف — هر مضمون جداگانه (خطای یک مضمون
 * بقیه را خراب نمی‌کند). */
export async function generateFinalExamQuestions(
  env: FinalExamAiBindings,
  opts: { gradeNumber: number; subjects: Array<{ id: string; nameFa: string }>; perSubjectCount?: number },
): Promise<Array<{ subjectId: string; questions: GeneratedFinalExamQuestion[] }>> {
  return Promise.all(
    opts.subjects.map(async (s) => ({
      subjectId: s.id,
      questions: await generateFinalExamQuestionsForSubject(env, {
        gradeNumber: opts.gradeNumber,
        subjectNameFa: s.nameFa,
        count: opts.perSubjectCount,
      }),
    })),
  );
}
