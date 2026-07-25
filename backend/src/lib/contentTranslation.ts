/**
 * lib/contentTranslation.ts — ترجمهٔ نصاب (مضمون/فصل/درس) به زبان‌های دیگر،
 * اول پشتو (بخش تازهٔ «نصاب چندزبانه»، طبق درخواست صاحب پروژه).
 *
 * معماری: محتوای دری اصلی (`subjects.name_fa`, `chapters.title_fa`,
 * `lessons.title_fa`/`content_body`) هرگز دست‌خورده نمی‌شود؛ هر ترجمه یک
 * ردیف جدا در `content_translations` (migration 0045) است. AI فقط
 * پیش‌نویس (`status='draft'`) می‌سازد — تا مدیر مرور/ویرایش و منتشر
 * (`status='published'`) نکند، هیچ شاگردی آن را نمی‌بیند (نگاه کنید به
 * `getPublishedTranslation` که فقط GET Endpointهای عمومی نصاب صدا می‌زنند).
 */
import { geminiGenerate, sanitizeDariText, DARI_OUTPUT_RULES, type GeminiEnv } from './gemini';

export type EntityType = 'subject' | 'chapter' | 'lesson';

export type TranslationRow = {
  id: string;
  entityType: EntityType;
  entityId: string;
  language: string;
  title: string;
  body: string;
  status: 'draft' | 'published';
  source: 'ai' | 'manual';
  translatedBy: string | null;
  createdAt: string;
  updatedAt: string;
};

/** نام کامل زبان برای پرامپت — فعلاً فقط پشتو، ساختار آماده برای آینده. */
const LANGUAGE_NAMES: Record<string, string> = {
  ps: 'پشتو',
  en: 'انگلیسی',
};

function rowToTranslation(r: any): TranslationRow {
  return {
    id: r.id,
    entityType: r.entity_type,
    entityId: r.entity_id,
    language: r.language,
    title: r.title,
    body: r.body,
    status: r.status,
    source: r.source,
    translatedBy: r.translated_by ?? null,
    createdAt: r.created_at,
    updatedAt: r.updated_at,
  };
}

export async function getTranslation(
  db: D1Database,
  entityType: EntityType,
  entityId: string,
  language: string,
): Promise<TranslationRow | null> {
  const row = await db
    .prepare('SELECT * FROM content_translations WHERE entity_type=? AND entity_id=? AND language=?')
    .bind(entityType, entityId, language)
    .first<any>();
  return row ? rowToTranslation(row) : null;
}

/** فقط ترجمهٔ منتشرشده — همان که Endpointهای عمومی نصاب باید مصرف کنند. */
export async function getPublishedTranslation(
  db: D1Database,
  entityType: EntityType,
  entityId: string,
  language: string,
): Promise<TranslationRow | null> {
  const t = await getTranslation(db, entityType, entityId, language);
  return t && t.status === 'published' ? t : null;
}

/** نگاشت گروهی (یک کوئری) — برای فهرست‌ها (مثل GET /subjects) به‌جای N کوئری جدا. */
export async function getPublishedTranslationsMap(
  db: D1Database,
  entityType: EntityType,
  entityIds: string[],
  language: string,
): Promise<Map<string, TranslationRow>> {
  const map = new Map<string, TranslationRow>();
  if (entityIds.length === 0) return map;
  const placeholders = entityIds.map(() => '?').join(',');
  const { results } = await db
    .prepare(
      `SELECT * FROM content_translations WHERE entity_type=? AND language=? AND status='published' AND entity_id IN (${placeholders})`,
    )
    .bind(entityType, language, ...entityIds)
    .all<any>();
  for (const r of results) map.set(r.entity_id, rowToTranslation(r));
  return map;
}

export async function getTranslationById(db: D1Database, id: string): Promise<TranslationRow | null> {
  const row = await db.prepare('SELECT * FROM content_translations WHERE id=?').bind(id).first<any>();
  return row ? rowToTranslation(row) : null;
}

export async function listTranslations(
  db: D1Database,
  opts: { entityType?: EntityType; entityId?: string; language?: string } = {},
): Promise<TranslationRow[]> {
  const conditions: string[] = [];
  const binds: unknown[] = [];
  if (opts.entityType) {
    conditions.push('entity_type = ?');
    binds.push(opts.entityType);
  }
  if (opts.entityId) {
    conditions.push('entity_id = ?');
    binds.push(opts.entityId);
  }
  if (opts.language) {
    conditions.push('language = ?');
    binds.push(opts.language);
  }
  const where = conditions.length ? `WHERE ${conditions.join(' AND ')}` : '';
  const { results } = await db
    .prepare(`SELECT * FROM content_translations ${where} ORDER BY updated_at DESC LIMIT 300`)
    .bind(...binds)
    .all<any>();
  return results.map(rowToTranslation);
}

export async function updateTranslationFields(
  db: D1Database,
  id: string,
  fields: { title?: string; body?: string; status?: 'draft' | 'published'; translatedBy?: string | null },
): Promise<TranslationRow | null> {
  const existing = await getTranslationById(db, id);
  if (!existing) return null;
  await db
    .prepare(
      `UPDATE content_translations SET title=COALESCE(?, title), body=COALESCE(?, body),
         status=COALESCE(?, status), source='manual', translated_by=COALESCE(?, translated_by),
         updated_at=datetime('now') WHERE id=?`,
    )
    .bind(fields.title ?? null, fields.body ?? null, fields.status ?? null, fields.translatedBy ?? null, id)
    .run();
  return getTranslationById(db, id);
}

export async function deleteTranslation(db: D1Database, id: string): Promise<boolean> {
  const existing = await getTranslationById(db, id);
  if (!existing) return false;
  await db.prepare('DELETE FROM content_translations WHERE id=?').bind(id).run();
  return true;
}

export async function upsertTranslation(
  db: D1Database,
  opts: {
    entityType: EntityType;
    entityId: string;
    language: string;
    title: string;
    body?: string;
    status?: 'draft' | 'published';
    source?: 'ai' | 'manual';
    translatedBy?: string | null;
  },
): Promise<TranslationRow> {
  const existing = await db
    .prepare('SELECT id FROM content_translations WHERE entity_type=? AND entity_id=? AND language=?')
    .bind(opts.entityType, opts.entityId, opts.language)
    .first<{ id: string }>();
  const id = existing?.id ?? `ctr_${crypto.randomUUID()}`;
  if (existing) {
    await db
      .prepare(
        `UPDATE content_translations SET title=?, body=?, status=COALESCE(?, status), source=COALESCE(?, source),
           translated_by=COALESCE(?, translated_by), updated_at=datetime('now') WHERE id=?`,
      )
      .bind(opts.title, opts.body ?? '', opts.status ?? null, opts.source ?? null, opts.translatedBy ?? null, id)
      .run();
  } else {
    await db
      .prepare(
        `INSERT INTO content_translations (id, entity_type, entity_id, language, title, body, status, source, translated_by)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(
        id,
        opts.entityType,
        opts.entityId,
        opts.language,
        opts.title,
        opts.body ?? '',
        opts.status ?? 'draft',
        opts.source ?? 'ai',
        opts.translatedBy ?? null,
      )
      .run();
  }
  const row = await db.prepare('SELECT * FROM content_translations WHERE id=?').bind(id).first<any>();
  return rowToTranslation(row);
}

export type TranslateAiResult = { status: 'ready'; title: string; body: string } | { status: 'rate_limited' } | { status: 'failed' };

/**
 * تولید پیش‌نویس ترجمهٔ یک مضمون/فصل/درس با Gemini. برای subject/chapter
 * فقط `title` معنا دارد؛ `sourceBody` اختیاری (فقط برای lesson) است.
 */
export async function translateWithAi(
  env: GeminiEnv,
  opts: {
    language: string;
    sourceTitle: string;
    sourceBody?: string;
    contextLabel: string; // مثلاً «عنوان مضمون», «عنوان فصل», «عنوان و متن کامل درس»
  },
): Promise<TranslateAiResult> {
  const languageName = LANGUAGE_NAMES[opts.language] ?? opts.language;
  const hasBody = (opts.sourceBody ?? '').trim().length > 0;

  const responseSchema = hasBody
    ? {
        type: 'OBJECT',
        properties: {
          title: { type: 'STRING', description: `عنوان ترجمه‌شده به ${languageName}` },
          body: { type: 'STRING', description: `متن کامل ترجمه‌شده به ${languageName} (Markdown)` },
        },
        required: ['title', 'body'],
      }
    : {
        type: 'OBJECT',
        properties: {
          title: { type: 'STRING', description: `عنوان ترجمه‌شده به ${languageName}` },
        },
        required: ['title'],
      };

  const prompt =
    `متن زیر (${opts.contextLabel}) را از فارسی/دری به ${languageName} ترجمه کن — نصاب رسمی معارف افغانستان:\n\n` +
    `عنوان: ${opts.sourceTitle}\n` +
    (hasBody ? `\nمتن کامل:\n${opts.sourceBody}\n` : '') +
    `\nقواعد ترجمه (دقیقاً رعایت شود):\n` +
    `۱. ترجمهٔ روان، دقیق و طبیعی به ${languageName} معیار افغانستان — نه ترجمهٔ کلمه‌به‌کلمهٔ ماشینی.\n` +
    `۲. اصطلاحات علمی/فنی را با معادل رایج و درست ${languageName} در معارف افغانستان برگردان.\n` +
    `۳. ساختار Markdown (سرخط‌ها، فهرست‌ها، جدول‌ها، پاراگراف‌بندی) دقیقاً مثل متن اصلی حفظ شود؛ هیچ بخشی حذف/خلاصه نشود.\n` +
    `۴. لحن آموزشی، گرم و محترمانه (مخاطب دانش‌آموز دختر) دقیقاً مثل متن مبدأ حفظ شود.\n` +
    `۵. لینک‌های تصویر (مثل ![...](...)) و فرمول‌ها بدون تغییر عیناً کپی شوند — فقط متن اطرافشان ترجمه شود.` +
    DARI_OUTPUT_RULES;

  const result = await geminiGenerate(env, {
    prompt,
    responseSchema,
    temperature: 0.3,
    maxOutputTokens: 8192,
    thinkingLevel: 'minimal',
  });

  if (!result.ok) {
    return result.rateLimited ? { status: 'rate_limited' } : { status: 'failed' };
  }

  try {
    const parsed = JSON.parse(result.text) as { title?: string; body?: string };
    const title = sanitizeDariText(String(parsed.title ?? '').trim());
    const body = hasBody ? sanitizeDariText(String(parsed.body ?? '').trim()) : '';
    if (!title) return { status: 'failed' };
    return { status: 'ready', title, body };
  } catch {
    return { status: 'failed' };
  }
}
