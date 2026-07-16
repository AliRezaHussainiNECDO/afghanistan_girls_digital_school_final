/**
 * lib/curriculumStructuring.ts — ساختاربندی خودکار متن یک کتاب آپلودشده به
 * فصل‌ها و درس‌ها، برای حالتی که شناسایی هوشمند سمت کلاینت (فونت/الگوی
 * متنی PDF، در `curriculum_library/domain/services/chapter_detector.dart`)
 * نتوانسته با اطمینان کافی فصل‌بندی کند (کمتر از ۲ فصل). در آن حالت،
 * کتابخانهٔ نصاب (`curriculum_library_books`) پر می‌شد اما جدول‌های
 * `chapters`/`lessons` — که نصاب داشبورد شاگردان از آن‌ها می‌خواند — خالی
 * می‌ماندند: دقیقاً همان اشکالِ «کتاب آپلود شد ولی هیچ درسی نمایش داده
 * نمی‌شود». این فایل روی سرور (بدون وابستگی به موفقیت تشخیص کلاینت) از
 * متن کامل ذخیره‌شدهٔ کتاب مستقیماً فصل/درس می‌سازد؛ تضمین می‌کند نصاب
 * هرگز به‌خاطر شکست یک هیوریستیک خالی نماند — قلب هماهنگی «مدیریت معلم
 * هوشمند» (مدیر) با «نصاب» (داشبورد شاگرد).
 *
 * دو لایه:
 *   ۱) تشخیص متنی (Deterministic) — بدون نیاز به هوش مصنوعی، همیشه برای
 *      هر متن غیرخالی نتیجه می‌دهد (فایل‌ ایمنِ نهایی).
 *   ۲) پرداخت عنوان با هوش مصنوعی (Best-effort، اختیاری) — فقط برای
 *      فصل‌هایی که عنوان واقعی در متن پیدا نشد (روش طول-محور)، عنوان‌های
 *      عمومی «فصل ۱» را به عنوان‌های معنادار بر اساس محتوای واقعی درس
 *      تبدیل می‌کند.
 */

export interface StructuredLesson {
  title: string;
  content: string;
}
export interface StructuredChapter {
  title: string;
  lessons: StructuredLesson[];
}

// ── رفع اصلاحی متن‌های قبلاً معکوس‌شده (RTL run reversal) ─────────────────
// همتای دقیق منطق سمت کلاینت در
// `lib/features/curriculum_library/domain/services/chapter_detector.dart`
// (`fixRtlRunOrder` / `_looksReversed`) — اما اینجا برای اصلاح **متنِ از قبل
// در دیتابیس ذخیره‌شده** (کتاب‌هایی که پیش از رفع اشکال کلاینت آپلود شده‌اند
// و ستون `extracted_text`شان همیشه معکوس باقی می‌ماند، چون فقط زمان آپلود
// استخراج می‌شود) به کار می‌رود. همان تصمیم خود-تصحیح‌گر: فقط وقتی به‌کار
// می‌رود که واقعاً معکوس‌شدگی را تشخیص دهد، پس هرگز متن از قبل درست را خراب
// نمی‌کند.

function isArabicScriptCodePoint(cp: number): boolean {
  return (
    (cp >= 0x0600 && cp <= 0x06ff) ||
    (cp >= 0x0750 && cp <= 0x077f) ||
    (cp >= 0x08a0 && cp <= 0x08ff) ||
    (cp >= 0xfb50 && cp <= 0xfdff) ||
    (cp >= 0xfe70 && cp <= 0xfeff)
  );
}

/** هر قطعهٔ پیوستهٔ نویسهٔ عربی/دری/پشتو («کلمه») را در خودش معکوس می‌کند —
 *  بدون دست‌زدن به فاصله‌ها، اعداد لاتین، یا ترتیب کلمات در خط. */
export function fixRtlRunOrder(line: string): string {
  const chars = Array.from(line); // با در نظر گرفتن جفت‌های surrogate
  if (chars.length === 0) return line;
  let out = '';
  let i = 0;
  while (i < chars.length) {
    const cp = chars[i].codePointAt(0) ?? 0;
    if (isArabicScriptCodePoint(cp)) {
      let j = i + 1;
      while (j < chars.length && isArabicScriptCodePoint(chars[j].codePointAt(0) ?? 0)) {
        j++;
      }
      for (let k = j - 1; k >= i; k--) out += chars[k];
      i = j;
    } else {
      out += chars[i];
      i++;
    }
  }
  return out;
}

const COMMON_DARI_WORDS = ['است', 'در', 'از', 'به', 'که', 'این', 'را', 'با', 'برای', 'هم', 'یک', 'می'];

function commonWordScore(text: string): number {
  let score = 0;
  for (const w of COMMON_DARI_WORDS) {
    let searchFrom = 0;
    for (;;) {
      const idx = text.indexOf(w, searchFrom);
      if (idx === -1) break;
      const before = idx > 0 ? text.codePointAt(idx - 1) : undefined;
      const afterIdx = idx + w.length;
      const after = afterIdx < text.length ? text.codePointAt(afterIdx) : undefined;
      const boundaryBefore = before === undefined || !isArabicScriptCodePoint(before);
      const boundaryAfter = after === undefined || !isArabicScriptCodePoint(after);
      if (boundaryBefore && boundaryAfter) score++;
      searchFrom = idx + w.length;
    }
  }
  return score;
}

function looksReversed(sample: string): boolean {
  if (!sample.trim()) return false;
  const originalScore = commonWordScore(sample);
  const fixedScore = commonWordScore(fixRtlRunOrder(sample));
  return fixedScore > originalScore;
}

export interface RtlFixResult {
  text: string;
  changed: boolean;
}

/**
 * اصلاح خود-تصحیح‌گر یک متنِ ذخیره‌شدهٔ کامل کتاب: روی یک نمونه (اولین
 * ~۴۰۰ خط) تصمیم می‌گیرد که آیا کل متن معکوس‌شده — اگر بله، هر خط را با
 * [fixRtlRunOrder] اصلاح می‌کند؛ اگر نه، متن دست‌نخورده برمی‌گردد.
 * `changed: false` یعنی متن از قبل درست بود (و فراخوان نباید کار اضافه‌ای
 * مثل بازسازی فصل‌ها انجام دهد).
 */
export function smartFixRtlText(rawText: string): RtlFixResult {
  if (!rawText || !rawText.trim()) return { text: rawText, changed: false };
  const lines = rawText.split(/\r?\n/);
  const sample = lines.slice(0, 400).join(' ');
  if (!looksReversed(sample)) return { text: rawText, changed: false };
  return { text: lines.map(fixRtlRunOrder).join('\n'), changed: true };
}

const CHAPTER_WORD_RE = /^\s*(فصل|بخش|باب|چپتر|Chapter|Unit)\s*[:\-–—]?\s*[\d۰-۹IVXLCM]*\s*[:\-–—]?\s*/i;
const LESSON_WORD_RE = /^\s*(درس|مبحث|گفتار|Lesson)\s*[:\-–—]?\s*[\d۰-۹]*\s*[:\-–—]?\s*/i;
const PAGE_NOISE_RE = /^[\d۰-۹\s\-–—._]{1,4}$/;

const MAX_TITLE_LEN = 90;
const MIN_LINES_BETWEEN_CHAPTERS = 12;
const MIN_LINES_BETWEEN_LESSONS = 4;
const MAX_CHUNK_CHARS = 1200;
/** بدون هیچ سرنخ عنوانی، هر ~۷۰۰۰ نویسه یک «فصل» فرض می‌شود. */
const FALLBACK_CHAPTER_CHARS = 7000;
const MAX_CHAPTERS = 60;
const MAX_LESSONS_PER_CHAPTER = 40;

function cleanLine(l: string): string {
  return l.trim();
}
function isNoise(l: string): boolean {
  return l.length === 0 || PAGE_NOISE_RE.test(l);
}

/** تقسیم یک بلوک خط بر اساس طول به چند «درس» کوتاه — هرگز یک بلوک غول‌آسا. */
function chunkByLength(lines: string[]): StructuredLesson[] {
  const cleaned = lines.map(cleanLine).filter((l) => !isNoise(l));
  if (cleaned.length === 0) return [];
  const lessons: StructuredLesson[] = [];
  let buf: string[] = [];
  let bufLen = 0;
  let count = 0;
  for (const line of cleaned) {
    if (bufLen + line.length > MAX_CHUNK_CHARS && buf.length) {
      count += 1;
      lessons.push({ title: `درس ${count}`, content: buf.join('\n').trim() });
      buf = [];
      bufLen = 0;
    }
    buf.push(line);
    bufLen += line.length;
  }
  if (buf.length) {
    count += 1;
    lessons.push({ title: `درس ${count}`, content: buf.join('\n').trim() });
  }
  // آخرین قطعهٔ خیلی کوتاه به قطعهٔ قبلی می‌چسبد (درسِ بی‌محتوا نداشته باشیم).
  if (lessons.length >= 2 && lessons[lessons.length - 1].content.length < 150) {
    const last = lessons.pop()!;
    const prev = lessons.pop()!;
    lessons.push({ title: prev.title, content: `${prev.content}\n${last.content}` });
  }
  return lessons.slice(0, MAX_LESSONS_PER_CHAPTER);
}

/** عنوان‌های درس داخل یک فصل را می‌یابد؛ در نبود اطمینان کافی، به تقسیم طولی برمی‌گردد. */
function splitIntoLessons(bodyLines: string[]): StructuredLesson[] {
  if (bodyLines.length === 0) return [];
  const candidates: number[] = [];
  for (let i = 0; i < bodyLines.length; i++) {
    const t = cleanLine(bodyLines[i]);
    if (t.length > 0 && t.length <= MAX_TITLE_LEN && LESSON_WORD_RE.test(t)) candidates.push(i);
  }
  const deduped: number[] = [];
  for (const idx of candidates) {
    if (deduped.length === 0 || idx - deduped[deduped.length - 1] >= MIN_LINES_BETWEEN_LESSONS) {
      deduped.push(idx);
    }
  }
  if (deduped.length >= 2) {
    const lessons: StructuredLesson[] = [];
    for (let k = 0; k < deduped.length; k++) {
      const start = deduped[k];
      const end = k + 1 < deduped.length ? deduped[k + 1] : bodyLines.length;
      const title = cleanLine(bodyLines[start]);
      const content = bodyLines
        .slice(start, end)
        .map(cleanLine)
        .filter((l) => !isNoise(l))
        .join('\n');
      if (content.trim()) lessons.push({ title: title || `درس ${k + 1}`, content });
    }
    if (lessons.length >= 2) return lessons.slice(0, MAX_LESSONS_PER_CHAPTER);
  }
  return chunkByLength(bodyLines);
}

export interface StructureResult {
  chapters: StructuredChapter[];
  /** true یعنی هیچ عنوان واقعی فصلی در متن پیدا نشد و همه‌چیز طول‌محور
   *  تقسیم شد — کاندیدِ خوب برای پرداخت عنوان با هوش مصنوعی. */
  usedFallback: boolean;
}

/** لایهٔ اول: تشخیص قطعی/بدون هوش مصنوعی — برای هر متن غیرخالی نتیجه می‌دهد. */
export function structureBookText(rawText: string): StructureResult {
  const lines = rawText.split(/\r?\n/);
  if (lines.every((l) => l.trim().length === 0)) return { chapters: [], usedFallback: false };

  const candidates: number[] = [];
  for (let i = 0; i < lines.length; i++) {
    const t = cleanLine(lines[i]);
    if (t.length > 0 && t.length <= MAX_TITLE_LEN && CHAPTER_WORD_RE.test(t)) candidates.push(i);
  }
  const deduped: number[] = [];
  for (const idx of candidates) {
    if (deduped.length === 0 || idx - deduped[deduped.length - 1] >= MIN_LINES_BETWEEN_CHAPTERS) {
      deduped.push(idx);
    }
  }

  if (deduped.length >= 2) {
    const chapters: StructuredChapter[] = [];
    for (let k = 0; k < deduped.length && chapters.length < MAX_CHAPTERS; k++) {
      const start = deduped[k];
      const end = k + 1 < deduped.length ? deduped[k + 1] : lines.length;
      const title = cleanLine(lines[start]).slice(0, 200);
      const lessons = splitIntoLessons(lines.slice(start + 1, end));
      if (lessons.length === 0) continue;
      chapters.push({ title: title || `فصل ${k + 1}`, lessons });
    }
    if (chapters.length >= 2) return { chapters, usedFallback: false };
  }

  // ── لایهٔ ایمن: بدون هیچ سرنخ عنوانی قابل‌اعتماد، خود متن به فصل‌هایی با
  // اندازهٔ ثابت تقسیم می‌شود — تضمین می‌کند نصاب هرگز خالی نماند.
  const cleanedAll = lines.map(cleanLine).filter((l) => !isNoise(l));
  if (cleanedAll.length === 0) return { chapters: [], usedFallback: false };

  const chapterBlocks: string[][] = [];
  let block: string[] = [];
  let blockLen = 0;
  for (const line of cleanedAll) {
    if (blockLen + line.length > FALLBACK_CHAPTER_CHARS && block.length) {
      chapterBlocks.push(block);
      block = [];
      blockLen = 0;
    }
    block.push(line);
    blockLen += line.length;
  }
  if (block.length) chapterBlocks.push(block);

  const chapters: StructuredChapter[] = chapterBlocks
    .slice(0, MAX_CHAPTERS)
    .map((blk, i) => ({ title: `فصل ${i + 1}`, lessons: chunkByLength(blk) }))
    .filter((c) => c.lessons.length > 0);

  return { chapters, usedFallback: true };
}

/**
 * لایهٔ دوم (اختیاری/بهترین‌تلاش): وقتی عنوان واقعی فصلی در کتاب پیدا نشد
 * (`usedFallback === true`)، عنوان‌های عمومی «فصل ۱» را با یک تماس واحد به
 * همان سرویس هوش مصنوعی (`AI_PROVIDER_KEY`) به عنوان‌های معنادار تبدیل
 * می‌کند. کاملاً Fail-safe: هر خطا فقط یعنی عنوان‌های عمومی باقی می‌مانند —
 * هرگز مسیر اصلی انتشار نصاب را کند/مختل نمی‌کند؛ باید بعد از درج، در
 * پس‌زمینه با `waitUntil` صدا زده شود.
 */
export async function aiRenameFallbackChapters(
  apiKey: string | undefined,
  apiUrl: string | undefined,
  model: string | undefined,
  bookTitle: string,
  chapters: StructuredChapter[],
): Promise<string[] | null> {
  if (!apiKey || chapters.length === 0) return null;
  const capped = chapters.slice(0, 40);
  const snippets = capped.map((c, i) => {
    const firstContent = c.lessons[0]?.content ?? '';
    return `${i + 1}. ${firstContent.replace(/\s+/g, ' ').slice(0, 220)}`;
  });
  const prompt =
    `این‌ها قطعه‌های ابتدایی فصل‌های متوالی از کتاب درسی «${bookTitle}» هستند. ` +
    `برای هر قطعه یک عنوان کوتاه و دقیق فارسی (حداکثر ۸ کلمه) به همان ترتیب بده. ` +
    `فقط یک آرایهٔ JSON از رشته‌ها برگردان، بدون هیچ توضیح اضافه:\n\n${snippets.join('\n')}`;

  try {
    const url = apiUrl ?? 'https://api.openai.com/v1/chat/completions';
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: model ?? 'gpt-4o-mini',
        messages: [
          {
            role: 'system',
            content: 'تو دستیار برچسب‌گذاری فهرست مطالب کتاب‌های درسی افغانستان هستی. فقط یک آرایهٔ JSON معتبر از رشته برمی‌گردانی.',
          },
          { role: 'user', content: prompt },
        ],
        temperature: 0.3,
        max_tokens: 900,
      }),
    });
    if (!res.ok) return null;
    const data = (await res.json()) as any;
    const text = data?.choices?.[0]?.message?.content?.trim() ?? '';
    const jsonStart = text.indexOf('[');
    const jsonEnd = text.lastIndexOf(']');
    if (jsonStart === -1 || jsonEnd === -1) return null;
    const parsed = JSON.parse(text.slice(jsonStart, jsonEnd + 1));
    if (!Array.isArray(parsed)) return null;
    return parsed.map((t: any) => String(t ?? '').trim().slice(0, 120)).filter(Boolean);
  } catch (_) {
    return null;
  }
}
