/**
 * routes/media.ts — چت انسانی (متن/صوت)، کتابخانهٔ PDF، فایل‌ها (R2)، و
 * رضایت‌نامه (بخش ۱۰، ۱۱ سند). زیر `/api/v1` mount می‌شود.
 *
 * فایل‌های صوتی چت و PDF کتاب‌ها روی R2 (بایندینگ BUCKET) ذخیره/خوانده
 * می‌شوند. دسترسی مدیر با JWT (نقش super_admin) کنترل می‌شود.
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';

type Bindings = {
  DB: D1Database;
  BUCKET: R2Bucket;
  JWT_SECRET: string;
};

const media = new Hono<{ Bindings: Bindings }>();

const uid = () => crypto.randomUUID();
const bannedWords = ['فحش', 'بد', 'احمق', 'لعنتی'];

type Participant = { id: string; name: string; className: string };

const dmIdFor = (a: string, b: string) => {
  const ids = [a, b].sort();
  return `dm_${ids[0]}_${ids[1]}`;
};

function forbid(c: any) {
  return c.json({ success: false, error: { code: 'FORBIDDEN', message_fa: 'دسترسی مجاز نیست', message_en: 'Forbidden' } }, 403);
}

async function me(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

async function isAdmin(c: any): Promise<boolean> {
  const u = await me(c);
  return u?.role === 'super_admin';
}

// ═══════════════════════════════ هم‌صنفی‌ها ═════════════════════════════════
// هم‌صنفی = سایر دانش‌آموزان فعال هم‌صنف (بخش ۱۰.۱الف — فقط بین هم‌صنفی‌ها).

media.get('/classmates', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const self = await c.env.DB.prepare('SELECT current_grade FROM users WHERE id = ?')
    .bind(u.sub)
    .first<{ current_grade: number | null }>();
  const grade = self?.current_grade ?? 0;
  const { results } = await c.env.DB.prepare(
    `SELECT id, first_name, last_name, avatar_url FROM users
     WHERE role='student' AND status='active' AND current_grade = ? AND id != ?
     ORDER BY first_name LIMIT 200`,
  )
    .bind(grade, u.sub)
    .all<{ id: string; first_name: string; last_name: string; avatar_url: string | null }>();
  return c.json(
    results.map((r) => ({
      id: r.id,
      name: `${r.first_name} ${r.last_name}`.trim(),
      classId: `grade-${grade}`,
      className: `صنف ${grade}`,
      avatarUrl: r.avatar_url,
    })),
  );
});

// ═══════════════════════════════ چت — شاگرد ═════════════════════════════════

media.post('/conversations', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const body = await c.req.json<{ type: 'dm' | 'admin'; classId: string; className: string; participants: Participant[] }>();
  const id =
    body.type === 'admin'
      ? `admin_${u.sub}`
      : dmIdFor(body.participants[0].id, body.participants[1].id);
  const existing = await c.env.DB.prepare('SELECT id FROM conversations WHERE id = ?').bind(id).first();
  if (!existing) {
    await c.env.DB.prepare(
      'INSERT INTO conversations (id, type, class_id, class_name, participants, last_message, last_message_at) VALUES (?, ?, ?, ?, ?, ?, datetime("now"))',
    )
      .bind(id, body.type, body.classId, body.className, JSON.stringify(body.participants), '')
      .run();
  }
  return c.json({ id });
});

media.get('/users/:userId/conversations', async (c) => {
  const userId = c.req.param('userId');
  const { results } = await c.env.DB.prepare(
    "SELECT * FROM conversations WHERE participants LIKE ? ORDER BY (type = 'admin') DESC, last_message_at DESC",
  )
    .bind(`%"${userId}"%`)
    .all();
  return c.json(results);
});

media.get('/conversations/:id/messages', async (c) => {
  const id = c.req.param('id');
  const viewerId = c.req.query('viewerId') ?? '';
  const { results } = await c.env.DB.prepare(
    `SELECT * FROM messages WHERE conversation_id = ?
       AND (sender_id = ? OR NOT (flagged = 1 AND review_status IN ('pending','rejected')))
     ORDER BY created_at ASC`,
  )
    .bind(id, viewerId)
    .all();
  return c.json(results);
});

media.post('/conversations/:id/messages', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const conversationId = c.req.param('id');
  const body = await c.req.json<{ senderName: string; senderClassName: string; text: string }>();
  const flagged = bannedWords.some((w) => body.text.includes(w));
  const id = uid();
  await c.env.DB.prepare(
    'INSERT INTO messages (id, conversation_id, sender_id, sender_name, sender_class_name, body, kind, flagged, review_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
  )
    .bind(id, conversationId, u.sub, body.senderName ?? '', body.senderClassName ?? '', body.text, 'text', flagged ? 1 : 0, flagged ? 'pending' : 'none')
    .run();
  await c.env.DB.prepare('UPDATE conversations SET last_message = ?, last_message_at = datetime("now") WHERE id = ?')
    .bind(flagged ? 'در انتظار بازبینی مدیر...' : body.text, conversationId)
    .run();

  // رفع اشکال هماهنگی: وقتی پیام در گفتگوی «کاربر ↔ مدیریت» فرستاده
  // می‌شود، همهٔ مدیران Super Admin باید فوراً اعلان واقعی بگیرند — قبلاً
  // این پیام‌ها فقط منتظر می‌ماندند تا مدیر خودش صندوق ورودی چت را دستی
  // باز کند.
  const conv = await c.env.DB.prepare('SELECT type FROM conversations WHERE id = ?')
    .bind(conversationId)
    .first<{ type: string }>();
  if (conv?.type === 'admin') {
    const { results: admins } = await c.env.DB.prepare("SELECT id FROM users WHERE role = 'super_admin'").all<{
      id: string;
    }>();
    for (const a of admins) {
      await c.env.DB.prepare(
        "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind) VALUES (?, ?, ?, ?, 'medium', 'chat')",
      )
        .bind(uid(), a.id, `پیام جدید از ${body.senderName || 'یک کاربر'} 💬`, body.text)
        .run();
    }
  }
  return c.json({ id, flagged });
});

// آپلود پیام صوتی روی R2: بدنه = بایت‌های audio/m4a، متادیتا در هدرها.
media.post('/conversations/:id/messages/voice', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const conversationId = c.req.param('id');
  const senderName = decodeURIComponent(c.req.header('X-Sender-Name') ?? '');
  const senderClassName = decodeURIComponent(c.req.header('X-Sender-Class') ?? '');
  const durationMs = Number(c.req.header('X-Duration-Ms') ?? '0');
  const audioKey = `voice/${conversationId}/${uid()}.m4a`;
  const bytes = await c.req.arrayBuffer();
  await c.env.BUCKET.put(audioKey, bytes, { httpMetadata: { contentType: 'audio/m4a' } });

  const id = uid();
  await c.env.DB.prepare(
    'INSERT INTO messages (id, conversation_id, sender_id, sender_name, sender_class_name, kind, audio_key, duration_ms) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
  )
    .bind(id, conversationId, u.sub, senderName, senderClassName, 'voice', audioKey, durationMs)
    .run();
  await c.env.DB.prepare('UPDATE conversations SET last_message = ?, last_message_at = datetime("now") WHERE id = ?')
    .bind('🎙 پیام صوتی', conversationId)
    .run();
  return c.json({ id, audioUrl: `/files/${audioKey}` });
});

// ═══════════════════════════ عکس پروفایل (R2) ═══════════════════════════════
// بدنه = بایت‌های خام تصویر (jpeg/png)، Content-Type در هدر. عکس در R2 با کلید
// ثابتِ هر کاربر ذخیره و users.avatar_url به‌روزرسانی می‌شود (با ?v= برای
// باطل‌شدن کش پس از هر تغییر).

media.post('/users/me/avatar', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const contentType = c.req.header('Content-Type') ?? 'image/jpeg';
  if (!contentType.startsWith('image/')) {
    return c.json({ success: false, error: { code: 'BAD_TYPE', message_fa: 'فقط فایل تصویری مجاز است', message_en: 'Image only' } }, 400);
  }
  const bytes = await c.req.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > 5 * 1024 * 1024) {
    return c.json({ success: false, error: { code: 'BAD_SIZE', message_fa: 'حجم عکس باید بین ۱ بایت و ۵ مگابایت باشد', message_en: 'Bad size' } }, 400);
  }
  const ext = contentType.includes('png') ? 'png' : 'jpg';
  const key = `avatars/${u.sub}.${ext}`;
  await c.env.BUCKET.put(key, bytes, { httpMetadata: { contentType } });
  const avatarUrl = `/files/${key}?v=${Date.now()}`;
  await c.env.DB.prepare("UPDATE users SET avatar_url = ?, updated_at = datetime('now') WHERE id = ?")
    .bind(avatarUrl, u.sub)
    .run();
  return c.json({ success: true, avatarUrl });
});

media.delete('/users/me/avatar', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  for (const ext of ['jpg', 'png']) {
    await c.env.BUCKET.delete(`avatars/${u.sub}.${ext}`);
  }
  await c.env.DB.prepare("UPDATE users SET avatar_url = NULL, updated_at = datetime('now') WHERE id = ?")
    .bind(u.sub)
    .run();
  return c.json({ success: true });
});

media.post('/messages/:id/report', async (c) => {
  const u = await me(c);
  if (!u) return c.json({ error: 'unauthorized' }, 401);
  const messageId = c.req.param('id');
  const body = await c.req.json<{ reason: string; reportedByName: string }>();
  await c.env.DB.prepare(
    'INSERT INTO chat_reports (id, message_id, reason, reported_by_id, reported_by_name) VALUES (?, ?, ?, ?, ?)',
  )
    .bind(uid(), messageId, body.reason, u.sub, body.reportedByName ?? '')
    .run();
  return c.json({ ok: true });
});

// ═══════════════════════════════ چت — مدیر ══════════════════════════════════

media.get('/admin/chat/overview', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const { results } = await c.env.DB.prepare(
    `SELECT conv.class_id, conv.class_name,
            COUNT(DISTINCT conv.id) AS conversation_count,
            COUNT(m.id) AS message_count,
            SUM(CASE WHEN m.flagged = 1 AND m.review_status = 'pending' THEN 1 ELSE 0 END) AS flagged_pending_count,
            MAX(conv.last_message_at) AS last_activity_at
     FROM conversations conv LEFT JOIN messages m ON m.conversation_id = conv.id
     GROUP BY conv.class_id, conv.class_name`,
  ).all();
  return c.json(results);
});

const CONV_WITH_COUNTS = `SELECT conv.*,
    (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = conv.id) AS message_count,
    (SELECT COUNT(*) FROM messages m WHERE m.conversation_id = conv.id AND m.flagged = 1 AND m.review_status = 'pending') AS flagged_pending_count
  FROM conversations conv`;

media.get('/admin/chat/classes/:classId/conversations', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const { results } = await c.env.DB.prepare(
    `${CONV_WITH_COUNTS} WHERE conv.class_id = ? ORDER BY conv.last_message_at DESC`,
  )
    .bind(c.req.param('classId'))
    .all();
  return c.json(results);
});

media.get('/admin/chat/inbox', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const { results } = await c.env.DB.prepare(
    `${CONV_WITH_COUNTS} WHERE conv.type = 'admin' ORDER BY conv.last_message_at DESC`,
  ).all();
  return c.json(results);
});

// اطلاعات یک گفتگو (برای صفحهٔ نظارتی مدیر روی یک گفتگوی خاص).
media.get('/admin/conversations/:id/info', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const row = await c.env.DB.prepare(`${CONV_WITH_COUNTS} WHERE conv.id = ?`)
    .bind(c.req.param('id'))
    .first();
  if (!row) return c.notFound();
  return c.json(row);
});

media.get('/admin/conversations/:id/messages', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const { results } = await c.env.DB.prepare(
    'SELECT * FROM messages WHERE conversation_id = ? ORDER BY created_at ASC',
  )
    .bind(c.req.param('id'))
    .all();
  return c.json(results);
});

media.post('/admin/messages/:id/review', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const body = await c.req.json<{ approve: boolean }>();
  await c.env.DB.prepare('UPDATE messages SET review_status = ? WHERE id = ?')
    .bind(body.approve ? 'approved' : 'rejected', c.req.param('id'))
    .run();
  return c.json({ ok: true });
});

media.post('/admin/conversations/:id/reply', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const conversationId = c.req.param('id');
  const body = await c.req.json<{ text: string }>();

  // رفع اشکال: اگر مدیر بخواهد پیش‌دستانه از داخل پروندهٔ خودِ کاربر (بخش
  // مدیریت کاربران) به او پیام بدهد و آن کاربر هنوز خودش گفتگویی با
  // مدیریت شروع نکرده باشد، ردیف conversations وجود ندارد. قبلاً در این
  // حالت پیام یتیم ثبت می‌شد و هرگز در فهرست «گفتگوهای من» آن کاربر دیده
  // نمی‌شد. حالا گفتگو با هویت واقعی کاربر (از جدول users) ساخته می‌شود —
  // دقیقاً با همان قرارداد شناسه‌ای که خودِ کاربر هنگام شروع گفتگو
  // می‌سازد: `admin_<userId>`.
  let conv = await c.env.DB.prepare('SELECT * FROM conversations WHERE id = ?')
    .bind(conversationId)
    .first<any>();
  let targetUserId: string | null = null;
  if (!conv && conversationId.startsWith('admin_')) {
    targetUserId = conversationId.slice('admin_'.length);
    const target = await c.env.DB.prepare(
      'SELECT id, first_name, last_name, role, current_grade FROM users WHERE id = ?',
    )
      .bind(targetUserId)
      .first<{ id: string; first_name: string; last_name: string; role: string; current_grade: number | null }>();
    if (!target) {
      return c.json(
        { success: false, error: { code: 'NOT_FOUND', message_fa: 'کاربر یافت نشد', message_en: 'User not found' } },
        404,
      );
    }
    const name = `${target.first_name} ${target.last_name}`.trim();
    const className =
      target.role === 'student' && target.current_grade
        ? `صنف ${target.current_grade}`
        : target.role === 'parent'
          ? 'والدین'
          : target.role === 'seminar_instructor'
            ? 'استادان'
            : '';
    const classId = target.role === 'student' && target.current_grade ? `grade-${target.current_grade}` : 'admin-support';
    await c.env.DB.prepare(
      'INSERT INTO conversations (id, type, class_id, class_name, participants, last_message, last_message_at) VALUES (?, ?, ?, ?, ?, ?, datetime("now"))',
    )
      .bind(
        conversationId,
        'admin',
        classId,
        className,
        JSON.stringify([
          { id: target.id, name, className },
          { id: 'admin', name: 'مدیریت و پشتیبانی مکتب', className: '' },
        ]),
        '',
      )
      .run();
  } else if (conv) {
    try {
      const parts = JSON.parse(conv.participants ?? '[]') as { id: string }[];
      targetUserId = parts.find((p) => p.id !== 'admin')?.id ?? null;
    } catch {
      targetUserId = null;
    }
  }

  const id = uid();
  await c.env.DB.prepare(
    "INSERT INTO messages (id, conversation_id, sender_id, sender_name, body, kind) VALUES (?, ?, 'admin', 'مدیریت و پشتیبانی مکتب', ?, 'text')",
  )
    .bind(id, conversationId, body.text)
    .run();
  await c.env.DB.prepare('UPDATE conversations SET last_message = ?, last_message_at = datetime("now") WHERE id = ?')
    .bind(body.text, conversationId)
    .run();

  // اعلان واقعی برای همان کاربر — تا در بخش اعلان‌های خودش (و نه فقط با
  // باز کردن دستیِ چت) ببیند که مدیریت پاسخ داده است.
  if (targetUserId) {
    await c.env.DB.prepare(
      "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind) VALUES (?, ?, ?, ?, 'medium', 'chat')",
    )
      .bind(uid(), targetUserId, 'پاسخ جدید از مدیریت مکتب 💬', body.text)
      .run();
  }

  return c.json({ id });
});

// ═══════════════════════════ فایل از R2 (صوت/PDF) ═══════════════════════════

media.get('/files/*', async (c) => {
  const key = c.req.path.split('/files/')[1] ?? '';
  const obj = await c.env.BUCKET.get(key);
  if (!obj) return c.notFound();
  return new Response(obj.body, {
    headers: { 'Content-Type': obj.httpMetadata?.contentType ?? 'application/octet-stream' },
  });
});

// ═══════════════════════════ کتابخانهٔ PDF (بخش ۱۱) ══════════════════════════

media.get('/books', async (c) => {
  const subjectId = c.req.query('subjectId');
  const stmt = subjectId
    ? c.env.DB.prepare('SELECT id, subject_id, title, page_count, pdf_key, uploaded_at FROM curriculum_books WHERE subject_id = ? ORDER BY uploaded_at DESC').bind(subjectId)
    : c.env.DB.prepare('SELECT id, subject_id, title, page_count, pdf_key, uploaded_at FROM curriculum_books ORDER BY uploaded_at DESC');
  const { results } = await stmt.all<any>();
  return c.json(
    results.map((b) => ({
      id: b.id,
      subjectId: b.subject_id,
      title: b.title,
      pageCount: b.page_count,
      fileUrl: `/files/${b.pdf_key}`,
      uploadedAt: b.uploaded_at,
    })),
  );
});

media.post('/books', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const form = await c.req.formData();
  const subjectId = String(form.get('subjectId') ?? '');
  const title = String(form.get('title') ?? '');
  const pageCount = Number(form.get('pageCount') ?? 0);
  const extractedText = String(form.get('extractedText') ?? '');
  const file = form.get('file') as File | null;
  if (!subjectId || !title || !file) return c.json({ error: 'missing fields' }, 400);
  const id = uid();
  const pdfKey = `books/${subjectId}/${id}.pdf`;
  await c.env.BUCKET.put(pdfKey, await file.arrayBuffer(), { httpMetadata: { contentType: 'application/pdf' } });
  await c.env.DB.prepare(
    'INSERT INTO curriculum_books (id, subject_id, title, page_count, pdf_key, extracted_text) VALUES (?, ?, ?, ?, ?, ?)',
  )
    .bind(id, subjectId, title, pageCount, pdfKey, extractedText)
    .run();
  return c.json({ id });
});

media.delete('/books/:id', async (c) => {
  if (!(await isAdmin(c))) return forbid(c);
  const id = c.req.param('id');
  const row = await c.env.DB.prepare('SELECT pdf_key FROM curriculum_books WHERE id = ?').bind(id).first<{ pdf_key: string }>();
  if (row) await c.env.BUCKET.delete(row.pdf_key);
  await c.env.DB.prepare('DELETE FROM curriculum_books WHERE id = ?').bind(id).run();
  return c.json({ ok: true });
});

// ═══════════════════════════ رضایت‌نامهٔ قوانین ══════════════════════════════

media.post('/consents', async (c) => {
  const body = await c.req.json<{ userId: string; version: string }>();
  await c.env.DB.prepare('INSERT INTO consents (id, user_id, version) VALUES (?, ?, ?)')
    .bind(uid(), body.userId, body.version)
    .run();
  return c.json({ ok: true });
});

export default media;
