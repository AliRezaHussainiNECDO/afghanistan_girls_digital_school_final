/**
 * routes/cms.ts — تألیف محتوای مدیر (بخش ۱۴.۳ سند). فقط Super Admin.
 * زیر `/api/v1/admin/cms` mount می‌شود.
 *
 * کتاب/درس/سؤال با گردش‌کار draft→approved→published روی D1 ذخیره می‌شوند.
 * (مدیریت Invite Code از روتر admin استفاده می‌کند: /admin/invite-codes*.)
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { logAudit, clientIp } from '../lib/audit';

type Bindings = { DB: D1Database; JWT_SECRET: string };

const cms = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function forbid(c: any) {
  return c.json({ success: false, error: { code: 'FORBIDDEN', message_fa: 'دسترسی مجاز نیست', message_en: 'Forbidden' } }, 403);
}
/**
 * فقط Super Admin. در صورت مجاز شناسهٔ مدیر را برمی‌گرداند (برای audit_logs)،
 * وگرنه null — truthiness آن با کاربردهای قبلی `if (!(await isAdmin(c)))`
 * سازگار می‌ماند.
 */
async function isAdmin(c: any): Promise<string | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  return p?.['role'] === 'super_admin' ? ((p['sub'] as string) ?? null) : null;
}

/** ثبت تغییر وضعیت/حذف محتوای CMS در لاگ بازبینی (بخش ۱۴.۳.۲/۲۰.۳). */
function auditCms(
  c: any,
  adminId: string,
  actionType: 'content_status_change' | 'content_delete',
  table: string,
  targetId: string,
  status?: string,
) {
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: adminId,
      actorRole: 'super_admin',
      actionType,
      targetTable: table,
      targetId,
      afterValue: status ? { status } : undefined,
      ipAddress: clientIp(c),
    }),
  );
}

// ───────────────────────────────── کتاب‌ها ──────────────────────────────────

cms.get('/books', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const { results } = await c.env.DB.prepare('SELECT * FROM cms_books ORDER BY updated_at DESC').all<any>();
  return c.json({ books: results.map(bookJson) });
});

cms.post('/books', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const b = await c.req.json<any>().catch(() => null);
  if (!b) return c.json({ error: 'bad_request' }, 400);
  const id = b.id && String(b.id).length > 0 ? String(b.id) : uid();
  await c.env.DB.prepare(
    `INSERT INTO cms_books (id, title, category, author, grade, chapters_count, description, status, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
     ON CONFLICT(id) DO UPDATE SET title=excluded.title, category=excluded.category, author=excluded.author,
       grade=excluded.grade, chapters_count=excluded.chapters_count, description=excluded.description,
       status=excluded.status, updated_at=datetime('now')`,
  )
    .bind(id, b.title ?? '', b.category ?? '', b.author ?? '', b.grade ?? '', Number(b.chaptersCount ?? 0), b.description ?? '', b.status ?? 'draft')
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM cms_books WHERE id = ?').bind(id).first<any>();
  return c.json({ book: bookJson(row) });
});

cms.patch('/books/:id/status', async (c) => {
  const aid = await isAdmin(c);
  if (!aid) return forbid(c);
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  await c.env.DB.prepare("UPDATE cms_books SET status=?, updated_at=datetime('now') WHERE id=?")
    .bind(b?.status ?? 'draft', c.req.param('id'))
    .run();
  auditCms(c, aid, 'content_status_change', 'cms_books', c.req.param('id'), b?.status ?? 'draft');
  return c.json({ success: true });
});

cms.delete('/books/:id', async (c) => {
  const aid = await isAdmin(c);
  if (!aid) return forbid(c);
  await c.env.DB.prepare('DELETE FROM cms_books WHERE id = ?').bind(c.req.param('id')).run();
  auditCms(c, aid, 'content_delete', 'cms_books', c.req.param('id'));
  return c.json({ success: true });
});

// ───────────────────────────────── دروس ─────────────────────────────────────

cms.get('/lessons', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const { results } = await c.env.DB.prepare('SELECT * FROM cms_lessons ORDER BY updated_at DESC').all<any>();
  return c.json({ lessons: results.map(lessonJson) });
});

cms.post('/lessons', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const b = await c.req.json<any>().catch(() => null);
  if (!b) return c.json({ error: 'bad_request' }, 400);
  const id = b.id && String(b.id).length > 0 ? String(b.id) : uid();
  await c.env.DB.prepare(
    `INSERT INTO cms_lessons (id, title, chapter_title, book_title, duration_minutes, content, status, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))
     ON CONFLICT(id) DO UPDATE SET title=excluded.title, chapter_title=excluded.chapter_title,
       book_title=excluded.book_title, duration_minutes=excluded.duration_minutes, content=excluded.content,
       status=excluded.status, updated_at=datetime('now')`,
  )
    .bind(id, b.title ?? '', b.chapterTitle ?? '', b.bookTitle ?? '', Number(b.durationMinutes ?? 0), b.content ?? '', b.status ?? 'draft')
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM cms_lessons WHERE id = ?').bind(id).first<any>();
  return c.json({ lesson: lessonJson(row) });
});

cms.patch('/lessons/:id/status', async (c) => {
  const aid = await isAdmin(c);
  if (!aid) return forbid(c);
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  await c.env.DB.prepare("UPDATE cms_lessons SET status=?, updated_at=datetime('now') WHERE id=?")
    .bind(b?.status ?? 'draft', c.req.param('id'))
    .run();
  auditCms(c, aid, 'content_status_change', 'cms_lessons', c.req.param('id'), b?.status ?? 'draft');
  return c.json({ success: true });
});

cms.delete('/lessons/:id', async (c) => {
  const aid = await isAdmin(c);
  if (!aid) return forbid(c);
  await c.env.DB.prepare('DELETE FROM cms_lessons WHERE id = ?').bind(c.req.param('id')).run();
  auditCms(c, aid, 'content_delete', 'cms_lessons', c.req.param('id'));
  return c.json({ success: true });
});

// ───────────────────────────────── سؤالات ───────────────────────────────────

cms.get('/questions', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const { results } = await c.env.DB.prepare('SELECT * FROM cms_questions ORDER BY updated_at DESC').all<any>();
  return c.json({ questions: results.map(questionJson) });
});

cms.post('/questions', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const b = await c.req.json<any>().catch(() => null);
  if (!b) return c.json({ error: 'bad_request' }, 400);
  const id = b.id && String(b.id).length > 0 ? String(b.id) : uid();
  const options = JSON.stringify(Array.isArray(b.options) ? b.options : []);
  await c.env.DB.prepare(
    `INSERT INTO cms_questions (id, text, difficulty, subject, type, options, answer, status, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
     ON CONFLICT(id) DO UPDATE SET text=excluded.text, difficulty=excluded.difficulty, subject=excluded.subject,
       type=excluded.type, options=excluded.options, answer=excluded.answer, status=excluded.status,
       updated_at=datetime('now')`,
  )
    .bind(id, b.text ?? '', b.difficulty ?? 'medium', b.subject ?? '', b.type ?? 'mcq', options, b.answer ?? '', b.status ?? 'draft')
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM cms_questions WHERE id = ?').bind(id).first<any>();
  return c.json({ question: questionJson(row) });
});

cms.patch('/questions/:id/status', async (c) => {
  const aid = await isAdmin(c);
  if (!aid) return forbid(c);
  const b = await c.req.json<{ status?: string }>().catch(() => null);
  await c.env.DB.prepare("UPDATE cms_questions SET status=?, updated_at=datetime('now') WHERE id=?")
    .bind(b?.status ?? 'draft', c.req.param('id'))
    .run();
  auditCms(c, aid, 'content_status_change', 'cms_questions', c.req.param('id'), b?.status ?? 'draft');
  return c.json({ success: true });
});

cms.delete('/questions/:id', async (c) => {
  const aid = await isAdmin(c);
  if (!aid) return forbid(c);
  await c.env.DB.prepare('DELETE FROM cms_questions WHERE id = ?').bind(c.req.param('id')).run();
  auditCms(c, aid, 'content_delete', 'cms_questions', c.req.param('id'));
  return c.json({ success: true });
});

function bookJson(r: any) {
  return {
    id: r.id, title: r.title, category: r.category, author: r.author, grade: r.grade,
    chaptersCount: r.chapters_count, description: r.description, status: r.status, updatedAt: r.updated_at,
  };
}
function lessonJson(r: any) {
  return {
    id: r.id, title: r.title, chapterTitle: r.chapter_title, bookTitle: r.book_title,
    durationMinutes: r.duration_minutes, content: r.content, status: r.status, updatedAt: r.updated_at,
  };
}
function questionJson(r: any) {
  return {
    id: r.id, text: r.text, difficulty: r.difficulty, subject: r.subject, type: r.type,
    options: JSON.parse(r.options ?? '[]'), answer: r.answer, status: r.status, updatedAt: r.updated_at,
  };
}

export default cms;
// (audit wiring v1 — بخش ۲۰.۳)
