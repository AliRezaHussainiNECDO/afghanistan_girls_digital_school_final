/**
 * routes/aiCurriculum.ts — تولید هوشمند نصاب (Pure AI Generation) + تصویرساز داخلی.
 *
 * جایگزین کامل جریان قدیمیِ «آپلود PDF کتاب»: مدیر فقط صنف (۷..۱۲) و مضمون
 * اساسی را از درپ‌داون انتخاب و «تولید هوشمند» را می‌زند؛ Gemini (منبع مطلق
 * محتوا) با ResponseSchema کل درخت کتاب (فصل‌ها ← درس‌ها) را برمی‌گرداند و
 * همین‌جا در جدول‌های واقعی نصاب (`chapters`/`lessons` — همان‌هایی که داشبورد
 * شاگرد، قفل زنجیره‌ای و کار خانگی از آن‌ها می‌خوانند) تزریق می‌شود.
 *
 * Endpointها (زیر `/api/v1`):
 *   POST /admin/curriculum/ai-generate        {gradeNumber, subjectId}  (فقط مدیر)
 *   GET  /admin/curriculum/tree?grade&subject درختوارهٔ کامل + وضعیت قفل پیش‌فرض (فقط مدیر)
 *   GET  /ai-images/:spec                     تصویر آموزشی تولید Gemini (کش R2، عمومی)
 *
 * سازگاری با سهمیهٔ رایگان: تولید درخت = فقط ۱ تماس Gemini؛ متن کامل هر درس
 * Lazy تولید می‌شود (lib/aiLessonContent.ts). خطای 429 هرگز سرور را کرش
 * نمی‌دهد — پاسخ خوانای AI_RATE_LIMITED برمی‌گردد (بدنهٔ ۴زبانه).
 *
 * 🚨 خط قرمز: هیچ تغییری در منطق امتیازدهی/فیصدی پیشرفت/«یاد گرفتم»/کار
 * خانگی — این فایل فقط محتوا تولید می‌کند و به همان جدول‌ها و شناسه‌های
 * سازگار با قبل (`source_book_id`) می‌نویسد.
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { geminiGenerate, geminiGenerateImage, rateLimitFailBody, DARI_OUTPUT_RULES, sanitizeDariText } from '../lib/gemini';
import { AI_PENDING_MARKER } from '../lib/aiLessonContent';
import { getChapterList } from '../lib/progress';
import { logAudit, clientIp } from '../lib/audit';

type Bindings = {
  DB: D1Database;
  BUCKET: R2Bucket;
  JWT_SECRET: string;
  GEMINI_API_KEY?: string;
  GEMINI_VISION_MODEL?: string;
  GEMINI_IMAGE_MODEL?: string;
};

const aic = new Hono<{ Bindings: Bindings }>();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function adminId(c: any): Promise<string | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return p?.['role'] === 'super_admin' ? ((p['sub'] as string) ?? null) : null;
}

/**
 * مضامین اساسی و رسمی هر صنف متوسطه/لیسه — تنها گزینه‌های مجاز تولید (بخش «معماری درختی»).
 *
 * ⚠️ اصلاح مهم: شناسه‌ها باید دقیقاً با seed جدول `subjects` در مهاجرت
 * 0003_curriculum.sql یکی باشند (مثلاً `dari_lit` نه `dari`) — وگرنه فصل‌های
 * تولیدشده با subject_id ناموجود ثبت می‌شوند و در داشبورد شاگرد (که بر اساس
 * جدول subjects می‌خواند) هرگز ظاهر نمی‌شوند. لیست کامل ۱۰ مضمون طبق مشخصات.
 */
export const CORE_SUBJECTS: { id: string; nameFa: string }[] = [
  { id: 'math', nameFa: 'ریاضی' },
  { id: 'physics', nameFa: 'فزیک' },
  { id: 'chemistry', nameFa: 'کیمیا' },
  { id: 'biology', nameFa: 'بیولوژی' },
  { id: 'english', nameFa: 'انگلیسی' },
  { id: 'dari_lit', nameFa: 'ادبیات دری' },
  { id: 'history', nameFa: 'تاریخ' },
  { id: 'geography', nameFa: 'جغرافیه' },
  { id: 'islamic', nameFa: 'تعلیمات اسلامی' },
  { id: 'computer', nameFa: 'کمپیوتر ساینس' },
];

/** شناسهٔ «کتاب مجازی هوش مصنوعی» — سازگار با ستون موجود chapters.source_book_id. */
export function aiBookId(grade: number, subjectId: string): string {
  return `aibook_g${grade}_${subjectId}`;
}

// ═══════════════ ۱) تولید هوشمند درخت کتاب (فقط مدیر) ═══════════════════════

const TREE_RESPONSE_SCHEMA = {
  type: 'OBJECT',
  properties: {
    bookTitle: { type: 'STRING', description: 'عنوان رسمی کتاب درسی' },
    chapters: {
      type: 'ARRAY',
      items: {
        type: 'OBJECT',
        properties: {
          title: { type: 'STRING', description: 'عنوان فصل به فارسی/دری' },
          lessons: {
            type: 'ARRAY',
            items: {
              type: 'OBJECT',
              properties: {
                title: { type: 'STRING', description: 'عنوان درس' },
                summary: { type: 'STRING', description: 'خلاصهٔ یک‌جمله‌ای محتوای درس' },
              },
              required: ['title', 'summary'],
            },
          },
        },
        required: ['title', 'lessons'],
      },
    },
  },
  required: ['bookTitle', 'chapters'],
};

aic.post('/admin/curriculum/ai-generate', async (c) => {
  const admin = await adminId(c);
  if (!admin) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);

  const b = await c.req.json<{ gradeNumber?: number; subjectId?: string }>().catch(() => null);
  const grade = Number(b?.gradeNumber ?? 0);
  const subjectId = String(b?.subjectId ?? '').trim();
  const subject = CORE_SUBJECTS.find((s) => s.id === subjectId);
  if (grade < 7 || grade > 12 || !subject) {
    return c.json(
      fail('BAD_REQUEST', 'صنف (۷ الی ۱۲) و یکی از مضامین اساسی لازم است', 'Grade 7-12 and a core subject are required', 'ټولګی (۷-۱۲) او یو اساسي مضمون اړین دی', 'La classe (7-12) et une matière principale sont requises'),
      400,
    );
  }
  if (!c.env.GEMINI_API_KEY) {
    return c.json(fail('AI_NOT_CONFIGURED', 'کلید Gemini روی سرور تنظیم نشده است', 'Gemini key not configured', 'د Gemini کیلي تنظیم شوې نه ده', "La clé Gemini n'est pas configurée"), 503);
  }

  const prompt =
    `تو متخصص نصاب تعلیمی رسمی معارف افغانستان هستی. با اتکا به حافظهٔ دانش خودت، ` +
    `فهرست کامل و واقعی کتاب درسی مضمون «${subject.nameFa}» صنف ${grade} معارف افغانستان را بازسازی کن:\n` +
    `• همهٔ فصل‌های کتاب رسمی، به همان ترتیب کتاب.\n` +
    `• زیر هر فصل، همهٔ درس‌های آن فصل (عنوان + خلاصهٔ یک‌جمله‌ای).\n` +
    `• عنوان‌ها فارسی/دری تمیز باشند (برای مضمون پشتو، عنوان پشتو مانعی ندارد).\n` +
    `• هیچ فصل یا درسی از قلم نیفتد؛ اگر در جزئیات تردید داری، نزدیک‌ترین ساختار استاندارد نصاب معارف را بده.` +
    DARI_OUTPUT_RULES;

  const result = await geminiGenerate(c.env, {
    prompt,
    responseSchema: TREE_RESPONSE_SCHEMA,
    temperature: 0.3,
    maxOutputTokens: 16384,
    thinkingLevel: 'low',
  });

  if (!result.ok) {
    if (result.rateLimited) return c.json(rateLimitFailBody(), 429);
    return c.json(
      { ...fail('AI_GENERATE_FAILED', 'تولید هوشمند ناموفق بود؛ دوباره تلاش کنید', 'Smart generation failed', 'هوښیار تولید ناکام شو', 'La génération intelligente a échoué'), detail: result.detail },
      502,
    );
  }

  let tree: { bookTitle?: string; chapters?: { title?: string; lessons?: { title?: string; summary?: string }[] }[] };
  try {
    tree = JSON.parse(result.text);
  } catch {
    return c.json(fail('AI_BAD_OUTPUT', 'خروجی مدل قابل‌تجزیه نبود؛ دوباره تلاش کنید', 'Unparsable model output', 'د ماډل محصول د تجزیې وړ نه و', 'Sortie du modèle non analysable'), 502);
  }
  const chapters = (tree.chapters ?? []).filter((ch) => (ch?.lessons ?? []).length > 0);
  if (!chapters.length) {
    return c.json(fail('AI_EMPTY_TREE', 'مدل هیچ فصلی تولید نکرد؛ دوباره تلاش کنید', 'Model returned no chapters', 'ماډل هیڅ فصل تولید نه کړ', "Le modèle n'a produit aucun chapitre"), 502);
  }

  const bookId = aiBookId(grade, subjectId);

  // ── جایگزینی کامل نسل قبلی همین کتابِ هوش مصنوعی (همان الگوی امن
  // applyChapterPublish در routes/admin.ts — بازدیدها/تکمیل‌های وابسته هم
  // پاک می‌شوند تا پیشرفت شاگردان با درخت تازه ناسازگار نماند).
  const { results: oldChapters } = await c.env.DB.prepare('SELECT id FROM chapters WHERE source_book_id = ?')
    .bind(bookId)
    .all<{ id: string }>();
  if (oldChapters.length) {
    const chIds = oldChapters.map((r) => r.id);
    const chPh = chIds.map(() => '?').join(',');
    const { results: oldLessons } = await c.env.DB.prepare(`SELECT id FROM lessons WHERE chapter_id IN (${chPh})`)
      .bind(...chIds)
      .all<{ id: string }>();
    if (oldLessons.length) {
      const lsIds = oldLessons.map((r) => r.id);
      const lsPh = lsIds.map(() => '?').join(',');
      await c.env.DB.prepare(`DELETE FROM student_lesson_views WHERE lesson_id IN (${lsPh})`).bind(...lsIds).run();
      try {
        await c.env.DB.prepare(`DELETE FROM lesson_embeddings WHERE lesson_id IN (${lsPh})`).bind(...lsIds).run();
      } catch (_) {
        /* جدول ممکن است مهاجرت نشده باشد */
      }
      await c.env.DB.prepare(`DELETE FROM lessons WHERE id IN (${lsPh})`).bind(...lsIds).run();
    }
    await c.env.DB.prepare(`DELETE FROM student_chapter_completions WHERE chapter_id IN (${chPh})`).bind(...chIds).run();
    await c.env.DB.prepare(`DELETE FROM chapters WHERE id IN (${chPh})`).bind(...chIds).run();
  }

  // ── درج درخت تازه — متن کامل هر درس Lazy تولید می‌شود (نشانگر AI_PENDING).
  const stmts: any[] = [];
  let lessonsCreated = 0;
  chapters.forEach((ch, i) => {
    const chapterId = `ch_${bookId}_${i}`;
    const chTitle = sanitizeDariText(String(ch.title ?? `فصل ${i + 1}`)).slice(0, 200) || `فصل ${i + 1}`;
    stmts.push(
      c.env.DB.prepare(
        'INSERT INTO chapters (id, grade_number, subject_id, title_fa, order_index, status, source_book_id) VALUES (?, ?, ?, ?, ?, ?, ?)',
      ).bind(chapterId, grade, subjectId, chTitle, i + 1, 'published', bookId),
    );
    (ch.lessons ?? []).forEach((ls, j) => {
      const lsTitle = sanitizeDariText(String(ls?.title ?? `درس ${j + 1}`)).slice(0, 200) || `درس ${j + 1}`;
      const summary = sanitizeDariText(String(ls?.summary ?? '')).slice(0, 500);
      lessonsCreated += 1;
      stmts.push(
        c.env.DB.prepare(
          'INSERT INTO lessons (id, chapter_id, title_fa, estimated_minutes, order_index, content_body, status) VALUES (?, ?, ?, ?, ?, ?, ?)',
        ).bind(`ls_${bookId}_${i}_${j}`, chapterId, lsTitle, 15, j + 1, `${AI_PENDING_MARKER}\n${summary}`, 'published'),
      );
    });
  });
  await c.env.DB.batch(stmts);

  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: admin,
      actorRole: 'super_admin',
      actionType: 'content_ai_generate',
      targetTable: 'chapters',
      targetId: bookId,
      afterValue: { grade, subjectId, chaptersCreated: chapters.length, lessonsCreated },
      ipAddress: clientIp(c),
    }),
  );

  return c.json(
    {
      success: true,
      bookTitle: String(tree.bookTitle ?? `${subject.nameFa} — صنف ${grade}`),
      chaptersCreated: chapters.length,
      lessonsCreated,
    },
    201,
  );
});

// ═══════════════ ۲) درختوارهٔ نظارتی مدیر (فصل‌ها ← درس‌ها + قفل پیش‌فرض) ═══════

aic.get('/admin/curriculum/tree', async (c) => {
  const admin = await adminId(c);
  if (!admin) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Forbidden', 'لاسرسی اجازه نه لري', 'Accès non autorisé'), 403);
  const grade = Number(c.req.query('grade') ?? '0');
  const subjectId = String(c.req.query('subject') ?? '').trim();
  if (grade < 7 || grade > 12 || !subjectId) {
    return c.json(fail('BAD_REQUEST', 'صنف و مضمون لازم است', 'Grade and subject required', 'ټولګی او مضمون اړین دي', 'La classe et la matière sont requises'), 400);
  }
  // قفل پیش‌فرض (شاگرد تازه = بدون هیچ پیشرفتی): فصل/درس اول باز، بقیه قفل.
  const chapterList = await getChapterList(c.env.DB, subjectId, grade, null);
  const tree = [] as any[];
  for (const ch of chapterList) {
    const { results: lessons } = await c.env.DB.prepare(
      `SELECT id, title_fa, order_index, content_body FROM lessons WHERE chapter_id=? AND status='published' ORDER BY order_index`,
    )
      .bind(ch.id)
      .all<{ id: string; title_fa: string; order_index: number; content_body: string }>();
    tree.push({
      id: ch.id,
      title_fa: ch.titleFa,
      order_index: ch.orderIndex,
      default_unlocked: ch.unlocked,
      lessons: lessons.map((l, idx) => ({
        id: l.id,
        title_fa: l.title_fa,
        order_index: l.order_index,
        // قفل پیش‌فرض درس: فقط اولین درسِ اولین فصل باز است.
        default_unlocked: ch.unlocked && idx === 0,
        content_generated: !(l.content_body ?? '').startsWith(AI_PENDING_MARKER),
      })),
    });
  }
  return c.json({ grade, subjectId, chapters: tree });
});

// ═══════════════ ۳) تصویرساز داخلی (کش R2 — لینک عمومی داخل Markdown درس) ═══════

const PLACEHOLDER_SVG =
  `<svg xmlns="http://www.w3.org/2000/svg" width="640" height="360" viewBox="0 0 640 360">` +
  `<rect width="640" height="360" rx="16" fill="#f1f5f9"/>` +
  `<circle cx="320" cy="150" r="46" fill="#cbd5e1"/>` +
  `<rect x="230" y="220" width="180" height="14" rx="7" fill="#cbd5e1"/>` +
  `<rect x="260" y="248" width="120" height="10" rx="5" fill="#e2e8f0"/></svg>`;

async function sha256Hex(s: string): Promise<string> {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

aic.get('/ai-images/:spec', async (c) => {
  // عمومی و بدون توکن — رندرکنندهٔ Markdown فلاتر Header احراز نمی‌فرستد؛
  // محتوای این تصاویر آموزشی و غیرحساس است.
  const spec = decodeURIComponent(c.req.param('spec')).replace(/\.png$/i, '').trim().slice(0, 300);
  if (!spec) return c.body(PLACEHOLDER_SVG, 200, { 'Content-Type': 'image/svg+xml' });

  const key = `ai_images/${await sha256Hex(spec)}.png`;
  try {
    const cached = await c.env.BUCKET.get(key);
    if (cached) {
      return new Response(cached.body, {
        headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=31536000, immutable' },
      });
    }
    const bytes = await geminiGenerateImage(c.env, spec.replace(/-/g, ' '));
    if (bytes) {
      c.executionCtx.waitUntil(c.env.BUCKET.put(key, bytes, { httpMetadata: { contentType: 'image/png' } }));
      return new Response(bytes, {
        headers: { 'Content-Type': 'image/png', 'Cache-Control': 'public, max-age=31536000, immutable' },
      });
    }
  } catch (err) {
    console.error('[ai-images] —', err);
  }
  // هر خطا/نبود سهمیه → Placeholder سبک؛ Markdown درس هرگز نمی‌شکند.
  return c.body(PLACEHOLDER_SVG, 200, { 'Content-Type': 'image/svg+xml', 'Cache-Control': 'public, max-age=600' });
});

export default aic;
