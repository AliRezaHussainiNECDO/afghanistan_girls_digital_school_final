/**
 * routes/memory.ts — «حافظهٔ جمعی» (پست‌ها و کامنت‌ها) روی سرور تا بین همهٔ
 * کاربران به‌اشتراک گذاشته شوند. زیر `/api/v1` mount می‌شود.
 *
 * هویت نویسنده همیشه از JWT گرفته می‌شود (نه از بدنهٔ کلاینت) — بخش ۴.
 * ویرایش/حذف فقط برای صاحب پست/کامنت یا مدیر مجاز است.
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
};

const memory = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

async function me(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

/** نام و نقش نویسنده از جدول users (منبع معتبر هویت). */
async function authorInfo(db: D1Database, userId: string) {
  const u = await db
    .prepare('SELECT first_name, last_name, role FROM users WHERE id = ?')
    .bind(userId)
    .first<{ first_name: string; last_name: string; role: string }>();
  return {
    name: u ? `${u.first_name} ${u.last_name}`.trim() : 'کاربر',
    isAdmin: u?.role === 'super_admin',
  };
}

/** ردیف DB → JSON هماهنگ با MemoryPost.fromJson فلاتر (camelCase). */
function postJson(r: any) {
  let images: string[] = [];
  let reactions: Record<string, string[]> = {};
  try {
    images = JSON.parse(r.images_json ?? '[]');
  } catch {
    images = [];
  }
  try {
    reactions = JSON.parse(r.reactions_json ?? '{}');
  } catch {
    reactions = {};
  }
  return {
    id: r.id,
    authorId: r.author_id,
    authorName: r.author_name,
    authorIsAdmin: r.author_is_admin === 1,
    authorAvatarBase64: r.author_avatar_b64 ?? null,
    body: r.body,
    imagesBase64: images,
    createdAt: r.created_at,
    updatedAt: r.updated_at ?? null,
    reactions,
  };
}

function commentJson(r: any) {
  return {
    id: r.id,
    postId: r.post_id,
    parentCommentId: r.parent_comment_id ?? null,
    authorId: r.author_id,
    authorName: r.author_name,
    authorIsAdmin: r.author_is_admin === 1,
    authorAvatarBase64: r.author_avatar_b64 ?? null,
    body: r.body,
    createdAt: r.created_at,
  };
}

// ───────────────────────────────── Posts ────────────────────────────────────

memory.get('/memory/posts', async (c) => {
  if (!(await me(c))) return c.json({ error: 'unauthorized' }, 401);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM memory_posts ORDER BY created_at DESC LIMIT 300',
  ).all<any>();
  return c.json({ posts: results.map(postJson) });
});

memory.post('/memory/posts', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const body = await c.req
    .json<{ body?: string; imagesBase64?: string[]; authorAvatarBase64?: string }>()
    .catch(() => null);
  const text = String(body?.body ?? '').trim();
  if (!text && !(body?.imagesBase64?.length)) {
    return c.json({ success: false, error: { code: 'EMPTY', message_fa: 'روایت خالی است', message_en: 'Empty' } }, 400);
  }
  const info = await authorInfo(c.env.DB, u.sub);
  const id = `post_${Date.now()}_${uid().slice(0, 8)}`;
  await c.env.DB.prepare(
    'INSERT INTO memory_posts (id, author_id, author_name, author_is_admin, author_avatar_b64, body, images_json) VALUES (?, ?, ?, ?, ?, ?, ?)',
  )
    .bind(
      id,
      u.sub,
      info.name,
      info.isAdmin ? 1 : 0,
      body?.authorAvatarBase64 ?? null,
      text,
      JSON.stringify(body?.imagesBase64 ?? []),
    )
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM memory_posts WHERE id = ?').bind(id).first<any>();
  return c.json({ post: postJson(row) }, 201);
});

memory.patch('/memory/posts/:id', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const id = c.req.param('id');
  const row = await c.env.DB.prepare('SELECT author_id FROM memory_posts WHERE id = ?').bind(id).first<{ author_id: string }>();
  if (!row) return c.json({ error: 'not found' }, 404);
  if (row.author_id !== u.sub && u.role !== 'super_admin') {
    return c.json({ success: false, error: { code: 'FORBIDDEN', message_fa: 'اجازه ویرایش ندارید', message_en: 'Forbidden' } }, 403);
  }
  const body = await c.req.json<{ body?: string; imagesBase64?: string[] }>().catch(() => null);
  await c.env.DB.prepare(
    "UPDATE memory_posts SET body = ?, images_json = ?, updated_at = datetime('now') WHERE id = ?",
  )
    .bind(String(body?.body ?? ''), JSON.stringify(body?.imagesBase64 ?? []), id)
    .run();
  const updated = await c.env.DB.prepare('SELECT * FROM memory_posts WHERE id = ?').bind(id).first<any>();
  return c.json({ post: postJson(updated) });
});

memory.delete('/memory/posts/:id', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const id = c.req.param('id');
  const row = await c.env.DB.prepare('SELECT author_id FROM memory_posts WHERE id = ?').bind(id).first<{ author_id: string }>();
  if (!row) return c.json({ success: true });
  if (row.author_id !== u.sub && u.role !== 'super_admin') {
    return c.json({ success: false, error: { code: 'FORBIDDEN', message_fa: 'اجازه حذف ندارید', message_en: 'Forbidden' } }, 403);
  }
  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM memory_comments WHERE post_id = ?').bind(id),
    c.env.DB.prepare('DELETE FROM memory_posts WHERE id = ?').bind(id),
  ]);
  return c.json({ success: true });
});

memory.post('/memory/posts/:id/reactions', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const id = c.req.param('id');
  const emoji = String((await c.req.json<{ emoji?: string }>().catch(() => null))?.emoji ?? '').trim();
  if (!emoji) return c.json({ error: 'bad request' }, 400);
  const row = await c.env.DB.prepare('SELECT * FROM memory_posts WHERE id = ?').bind(id).first<any>();
  if (!row) return c.json({ error: 'not found' }, 404);

  let reactions: Record<string, string[]> = {};
  try {
    reactions = JSON.parse(row.reactions_json ?? '{}');
  } catch {
    reactions = {};
  }
  const list = reactions[emoji] ?? [];
  const i = list.indexOf(u.sub);
  if (i >= 0) {
    list.splice(i, 1);
    if (list.length === 0) delete reactions[emoji];
    else reactions[emoji] = list;
  } else {
    list.push(u.sub);
    reactions[emoji] = list;
  }
  await c.env.DB.prepare('UPDATE memory_posts SET reactions_json = ? WHERE id = ?')
    .bind(JSON.stringify(reactions), id)
    .run();
  const updated = await c.env.DB.prepare('SELECT * FROM memory_posts WHERE id = ?').bind(id).first<any>();
  return c.json({ post: postJson(updated) });
});

// ─────────────────────────────── Comments ───────────────────────────────────

memory.get('/memory/posts/:id/comments', async (c) => {
  if (!(await me(c))) return c.json({ error: 'unauthorized' }, 401);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM memory_comments WHERE post_id = ? ORDER BY created_at ASC',
  )
    .bind(c.req.param('id'))
    .all<any>();
  return c.json({ comments: results.map(commentJson) });
});

memory.post('/memory/posts/:id/comments', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const postId = c.req.param('id');
  const body = await c.req
    .json<{ body?: string; parentCommentId?: string; authorAvatarBase64?: string }>()
    .catch(() => null);
  const text = String(body?.body ?? '').trim();
  if (!text) return c.json({ error: 'empty' }, 400);
  const info = await authorInfo(c.env.DB, u.sub);
  const id = `comment_${Date.now()}_${uid().slice(0, 8)}`;
  await c.env.DB.prepare(
    'INSERT INTO memory_comments (id, post_id, parent_comment_id, author_id, author_name, author_is_admin, author_avatar_b64, body) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  )
    .bind(
      id,
      postId,
      body?.parentCommentId ?? null,
      u.sub,
      info.name,
      info.isAdmin ? 1 : 0,
      body?.authorAvatarBase64 ?? null,
      text,
    )
    .run();
  const row = await c.env.DB.prepare('SELECT * FROM memory_comments WHERE id = ?').bind(id).first<any>();
  return c.json({ comment: commentJson(row) }, 201);
});

memory.delete('/memory/comments/:id', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const id = c.req.param('id');
  const row = await c.env.DB.prepare('SELECT author_id FROM memory_comments WHERE id = ?').bind(id).first<{ author_id: string }>();
  if (!row) return c.json({ success: true });
  if (row.author_id !== u.sub && u.role !== 'super_admin') {
    return c.json({ success: false, error: { code: 'FORBIDDEN', message_fa: 'اجازه حذف ندارید', message_en: 'Forbidden' } }, 403);
  }
  // حذف کامنت + پاسخ‌هایش (یک سطح Reply).
  await c.env.DB.prepare('DELETE FROM memory_comments WHERE id = ? OR parent_comment_id = ?')
    .bind(id, id)
    .run();
  return c.json({ success: true });
});

export default memory;
