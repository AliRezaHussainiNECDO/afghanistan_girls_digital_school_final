/**
 * routes/parents.ts — پیوند والد-فرزند و داشبورد والد (بخش ۲.۴ و ۱۳ب سند).
 *
 * Endpointها (زیر `/api/v1`):
 *   POST  /students/me/guardian-code           (دانش‌آموز) تولید کد دعوت والد
 *   GET   /students/me/guardian-code           (دانش‌آموز) کد فعال فعلی
 *   POST  /parents/link-requests               (والد) ثبت کد → درخواست پیوند
 *   GET   /students/me/parent-links?status=     (دانش‌آموز) درخواست‌های پیوند
 *   PATCH /students/me/parent-links/:id         (دانش‌آموز) تأیید/رد
 *   GET   /parents/me/children                  (والد) فرزندان تأییدشده
 *   GET   /parents/me/children/:sid/summary     (والد) کارنامهٔ زندهٔ فرزند — پیشرفت و امتیاز دقیقاً مطابق داشبورد شاگرد
 *   GET   /parents/me/pending-links              (والد) درخواست‌های ارسالی‌ای که هنوز فرزند تأیید نکرده (۲۴ جولای)
 */
import { Hono } from 'hono';
import { verifyBearer } from '../lib/auth';
import { getSubjectProgressList, averagePercent, getPointsSummary } from '../lib/progress';
import { logAudit, clientIp } from '../lib/audit';
import { sendPushToUser } from '../lib/push';

type Bindings = {
  DB: D1Database;
  JWT_SECRET: string;
  FCM_PROJECT_ID?: string;
  FCM_CLIENT_EMAIL?: string;
  FCM_PRIVATE_KEY?: string;
};

const parents = new Hono<{ Bindings: Bindings }>();
const uid = () => crypto.randomUUID();

function fail(code: string, fa: string, en: string, ps?: string, fr?: string) {
  return { success: false, error: { code, message_fa: fa, message_en: en, message_ps: ps ?? en, message_fr: fr ?? en } };
}

async function auth(c: any): Promise<{ sub: string; role: string } | null> {
  const p = await verifyBearer(c.req.header('Authorization'), c.env.JWT_SECRET);
  if (!p?.['sub']) return null;
  return { sub: p['sub'] as string, role: (p['role'] as string) ?? 'student' };
}

// ═════════════════════ سمت دانش‌آموز: تولید کد دعوت ═════════════════════════
// کد ۶ رقمی با عمر ۷۲ ساعت (بخش ۲.۴). هر بار تولید، کد قبلی جایگزین می‌شود.

parents.post('/students/me/guardian-code', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  let code = '';
  for (let i = 0; i < 6; i++) code += Math.floor(Math.random() * 10).toString();
  const expiresAt = new Date(Date.now() + 72 * 3600 * 1000).toISOString();
  await c.env.DB.prepare(
    `INSERT INTO guardian_codes (student_user_id, code, expires_at) VALUES (?, ?, ?)
     ON CONFLICT(student_user_id) DO UPDATE SET code=excluded.code, expires_at=excluded.expires_at, created_at=datetime('now')`,
  )
    .bind(me.sub, code, expiresAt)
    .run();
  return c.json({ code, expiresAt });
});

parents.get('/students/me/guardian-code', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const row = await c.env.DB.prepare(
    "SELECT code, expires_at FROM guardian_codes WHERE student_user_id = ? AND expires_at > datetime('now')",
  )
    .bind(me.sub)
    .first<{ code: string; expires_at: string }>();
  return c.json({ code: row?.code ?? null, expiresAt: row?.expires_at ?? null });
});

// ═════════════════════ سمت والد: ثبت کد → درخواست پیوند ══════════════════════

parents.post('/parents/link-requests', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const b = await c.req.json<{ code?: string }>().catch(() => null);
  const code = String(b?.code ?? '').trim();
  if (code.length !== 6) {
    return c.json(fail('INVALID_CODE', 'کد دعوت باید ۶ رقم باشد', 'Code must be 6 digits', 'د بلنې کوډ باید ۶ رقمونه وي', 'Le code d\'invitation doit comporter 6 chiffres'), 400);
  }
  const gc = await c.env.DB.prepare(
    "SELECT student_user_id FROM guardian_codes WHERE code = ? AND expires_at > datetime('now')",
  )
    .bind(code)
    .first<{ student_user_id: string }>();
  if (!gc) {
    return c.json(fail('INVALID_CODE', 'کد دعوت نامعتبر یا منقضی است', 'Invalid or expired code', 'د بلنې کوډ نامعتبر یا پای ته رسیدلی دی', 'Code d\'invitation invalide ou expiré'), 404);
  }
  const studentId = gc.student_user_id;

  // پیوند موجود؟
  const existing = await c.env.DB.prepare(
    'SELECT status FROM parent_student_links WHERE parent_user_id = ? AND student_user_id = ?',
  )
    .bind(me.sub, studentId)
    .first<{ status: string }>();
  if (existing?.status === 'approved') {
    return c.json(fail('ALREADY_LINKED', 'این فرزند قبلاً به شما لینک شده است', 'Already linked', 'دا ماشوم دمخه له تاسو سره تړل شوی دی', 'Cet enfant est déjà lié à vous'), 409);
  }
  if (existing?.status === 'pending_student_approval') {
    return c.json(fail('PENDING', 'درخواست قبلی هنوز در انتظار تأیید است', 'Request pending', 'پخوانۍ غوښتنه لاهم د تایید په تمه ده', 'La demande précédente est toujours en attente de validation'), 409);
  }

  // نام والد.
  const pu = await c.env.DB.prepare('SELECT first_name, last_name FROM users WHERE id = ?')
    .bind(me.sub)
    .first<{ first_name: string; last_name: string }>();
  const parentName = pu ? `${pu.first_name} ${pu.last_name}`.trim() : '';
  // نام فرزند (برای پیام والد).
  const su = await c.env.DB.prepare('SELECT first_name, last_name FROM users WHERE id = ?')
    .bind(studentId)
    .first<{ first_name: string; last_name: string }>();
  const studentName = su ? `${su.first_name} ${su.last_name}`.trim() : 'فرزند';

  if (existing?.status === 'rejected') {
    await c.env.DB.prepare(
      "UPDATE parent_student_links SET status='pending_student_approval', parent_name=?, created_at=datetime('now') WHERE parent_user_id=? AND student_user_id=?",
    )
      .bind(parentName, me.sub, studentId)
      .run();
  } else {
    await c.env.DB.prepare(
      'INSERT INTO parent_student_links (id, parent_user_id, student_user_id, parent_name) VALUES (?, ?, ?, ?)',
    )
      .bind(uid(), me.sub, studentId, parentName)
      .run();
  }
  // اعلان به دانش‌آموز — kind='account' (نه 'general') تا لمس آن دقیقاً به
  // پروفایل (جایی که درخواست پیوند تأیید/رد می‌شود) هدایت شود، نه یک مقصد
  // نامشخص.
  await c.env.DB.prepare(
    "INSERT INTO notifications (id, user_id, title_fa, body_fa, priority, kind, related_id) VALUES (?, ?, ?, ?, 'medium', 'account', ?)",
  )
    .bind(uid(), studentId, 'درخواست پیوند والد', `«${parentName}» درخواست اتصال به حساب شما را دارد. لطفاً تأیید یا رد کنید.`, me.sub)
    .run();
  c.executionCtx.waitUntil(
    sendPushToUser(c.env, studentId, 'درخواست پیوند والد', `«${parentName}» درخواست اتصال به حساب شما را دارد. لطفاً تأیید یا رد کنید.`, {
      kind: 'account',
      relatedId: me.sub,
    }),
  );
  // Auditability (بخش ۲۰.۳ — «تأیید/رد پیوند Parent-Student ثبت می‌شود»).
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: me.sub,
      actorRole: 'parent',
      actionType: 'parent_link_request',
      targetTable: 'parent_student_links',
      targetId: studentId,
      ipAddress: clientIp(c),
    }),
  );
  return c.json({ success: true, studentName });
});

// ═════════════════════ سمت دانش‌آموز: تأیید/رد پیوند ═════════════════════════

parents.get('/students/me/parent-links', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const status = c.req.query('status');
  const clauses = ['student_user_id = ?'];
  const binds: any[] = [me.sub];
  if (status) {
    clauses.push('status = ?');
    binds.push(status);
  }
  const { results } = await c.env.DB.prepare(
    `SELECT id, parent_user_id, parent_name, status, created_at FROM parent_student_links
     WHERE ${clauses.join(' AND ')} ORDER BY created_at DESC`,
  )
    .bind(...binds)
    .all<any>();
  return c.json({
    links: results.map((l) => ({
      id: l.id,
      parentId: l.parent_user_id,
      parentName: l.parent_name,
      status: l.status,
      createdAt: l.created_at,
    })),
  });
});

parents.patch('/students/me/parent-links/:id', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const b = await c.req.json<{ action?: string }>().catch(() => null);
  const action = b?.action;
  if (action !== 'approve' && action !== 'reject') {
    return c.json(fail('BAD_REQUEST', 'اقدام نامعتبر', 'Invalid action', 'ناسمه کړنه', 'Action invalide'), 400);
  }
  const link = await c.env.DB.prepare(
    "SELECT id, parent_user_id FROM parent_student_links WHERE id = ? AND student_user_id = ? AND status='pending_student_approval'",
  )
    .bind(c.req.param('id'), me.sub)
    .first<{ id: string; parent_user_id: string }>();
  if (!link) return c.json(fail('NOT_FOUND', 'درخواست یافت نشد', 'Request not found', 'غوښتنه ونه موندل شوه', 'Demande introuvable'), 404);
  const next = action === 'approve' ? 'approved' : 'rejected';
  await c.env.DB.prepare(
    "UPDATE parent_student_links SET status=?, approved_at=datetime('now') WHERE id=?",
  )
    .bind(next, link.id)
    .run();
  // Auditability (بخش ۲۰.۳): تصمیم دانش‌آموز روی پیوند والد.
  c.executionCtx.waitUntil(
    logAudit(c.env.DB, {
      actorId: me.sub,
      actorRole: 'student',
      actionType: 'parent_link_decision',
      targetTable: 'parent_student_links',
      targetId: link.id,
      afterValue: { status: next, parentUserId: link.parent_user_id },
      ipAddress: clientIp(c),
    }),
  );
  return c.json({ success: true, status: next });
});

// ═════════════════════════ سمت والد: فرزندان ════════════════════════════════

parents.get('/parents/me/children', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const { results } = await c.env.DB.prepare(
    `SELECT l.student_user_id, u.first_name, u.last_name
     FROM parent_student_links l JOIN users u ON u.id = l.student_user_id
     WHERE l.parent_user_id = ? AND l.status='approved'`,
  )
    .bind(me.sub)
    .all<{ student_user_id: string; first_name: string; last_name: string }>();
  return c.json({
    children: results.map((r) => ({
      studentId: r.student_user_id,
      displayName: `${r.first_name} ${r.last_name}`.trim(),
    })),
  });
});

// درخواست‌های پیوندی که این والد فرستاده و هنوز فرزند تأیید/رد نکرده
// (بخش ۱۳ب.۲: LINK_PENDING_STUDENT_APPROVAL). رفع اشکال (۲۴ جولای): پیش از
// این، داشبورد والد در Flutter این بخش را از یک Store محلی-فقط-Mock
// می‌خواند که هرگز با سرور همگام نبود — در حالت Live همیشه خالی می‌ماند.
// این Endpoint معادل واقعی همان چیزی است که آن Store قرار بود شبیه‌سازی کند.
parents.get('/parents/me/pending-links', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const { results } = await c.env.DB.prepare(
    `SELECT l.id, l.student_user_id, u.first_name, u.last_name
     FROM parent_student_links l JOIN users u ON u.id = l.student_user_id
     WHERE l.parent_user_id = ? AND l.status='pending_student_approval'
     ORDER BY l.created_at DESC`,
  )
    .bind(me.sub)
    .all<{ id: string; student_user_id: string; first_name: string; last_name: string }>();
  return c.json({
    links: results.map((r) => ({
      id: r.id,
      studentId: r.student_user_id,
      studentName: `${r.first_name} ${r.last_name}`.trim(),
    })),
  });
});

// کارنامهٔ زندهٔ فرزند — فقط اگر پیوند approved باشد (Allow-list بخش ۱۳ب.۳).
// پیشرفت هر مضمون و امتیاز فعالیت از lib/progress.ts می‌آید — همان منبعی که
// داشبورد خود شاگرد استفاده می‌کند، تا عدد اینجا دقیقاً با آنجا یکسان باشد.
parents.get('/parents/me/children/:sid/summary', async (c) => {
  const me = await auth(c);
  if (!me) return c.json(fail('UNAUTHORIZED', 'وارد نشده‌اید', 'Unauthorized', 'تاسو ننوتلي نه یاست', 'Vous n\'êtes pas connecté(e)'), 401);
  const studentId = c.req.param('sid');

  const link = await c.env.DB.prepare(
    "SELECT 1 FROM parent_student_links WHERE parent_user_id=? AND student_user_id=? AND status='approved'",
  )
    .bind(me.sub, studentId)
    .first();
  if (!link) return c.json(fail('FORBIDDEN', 'دسترسی مجاز نیست', 'Not linked', 'لاسرسی اجازه نه لري', 'Non lié'), 403);

  const student = await c.env.DB.prepare('SELECT first_name, last_name, current_grade FROM users WHERE id = ?')
    .bind(studentId)
    .first<{ first_name: string; last_name: string; current_grade: number | null }>();
  const grade = student?.current_grade ?? 7;
  const displayName = student ? `${student.first_name} ${student.last_name}`.trim() : 'فرزند';

  // پیشرفت هر مضمون (منبع واحد — همان محاسبهٔ داشبورد شاگرد) + میانگین امتحان جداگانه.
  const subjectsProgress = await getSubjectProgressList(c.env.DB, studentId, grade);
  const { results: examAvgRows } = await c.env.DB.prepare(
    `SELECT s.id,
       (SELECT AVG(a.score_percent) FROM exam_attempts a JOIN exams e ON e.id=a.exam_id
          WHERE a.user_id=? AND e.subject_id=s.id AND e.grade_number=?) AS avg_score
     FROM subjects s ORDER BY s.order_index`,
  )
    .bind(studentId, grade)
    .all<{ id: string; avg_score: number | null }>();
  const examAvgMap = new Map(examAvgRows.map((r) => [r.id, r.avg_score]));

  let completedCount = 0;
  const subjectSummaries = subjectsProgress.map((sp) => {
    let statusLabel: string;
    if (sp.status === 'completed') {
      statusLabel = 'completed';
      completedCount++;
    } else if (sp.status === 'inProgress') {
      statusLabel = 'in_progress';
    } else {
      statusLabel = 'locked';
    }
    const avgScore = examAvgMap.get(sp.subjectId) ?? null;
    return {
      subjectNameFa: sp.nameFa,
      statusLabel,
      progressPercent: sp.percent,
      finalScore: avgScore != null ? Math.round(avgScore * 10) / 10 : null,
    };
  });
  const gradeCompletion = averagePercent(subjectsProgress);

  // حاضری از فعالیت واقعی ۱۴ روز اخیر (بخش ۹.۱).
  const { results: actDays } = await c.env.DB.prepare(
    `SELECT DISTINCT d FROM (
        SELECT date(viewed_at) AS d FROM student_lesson_views WHERE user_id=? AND viewed_at>=date('now','-13 days')
        UNION SELECT date(submitted_at) AS d FROM exam_attempts WHERE user_id=? AND submitted_at>=date('now','-13 days'))`,
  )
    .bind(studentId, studentId)
    .all<{ d: string }>();
  const attendanceRate = Math.round((actDays.length / 14) * 1000) / 10;

  // گواهی‌نامه‌ها.
  const { results: certs } = await c.env.DB.prepare(
    'SELECT grade, year_label, honor FROM certificates WHERE student_id = ? ORDER BY issued_at DESC',
  )
    .bind(studentId)
    .all<{ grade: number; year_label: string; honor: string }>();
  const certificateTitles = certs.map(
    (ct) => `گواهی‌نامهٔ ختم صنف ${ct.grade}${ct.year_label ? ' — ' + ct.year_label : ''}${ct.honor ? ' (' + ct.honor + ')' : ''}`,
  );

  // سمینارهای پیش رو (عنوان).
  const { results: sems } = await c.env.DB.prepare(
    "SELECT title FROM seminars WHERE audience='students' AND status IN ('published','registrationClosed','live') ORDER BY scheduled_start LIMIT 3",
  ).all<{ title: string }>();

  // امتیاز فعالیت (Gamification) — همان امتیازی که در خانهٔ شاگرد نمایش داده می‌شود.
  const points = await getPointsSummary(c.env.DB, studentId);

  // دستاوردهای ساده از دادهٔ واقعی.
  const achievements: string[] = [];
  if (completedCount >= 1) achievements.push(`تکمیل ${completedCount} مضمون`);
  if (attendanceRate >= 75) achievements.push('حاضری منظم');
  if (certs.length > 0) achievements.push('دارندهٔ گواهی‌نامه');
  if (points.totalPoints >= 100) achievements.push(`رسیدن به سطح «${points.levelTitleFa}»`);

  return c.json({
    studentId,
    displayName,
    gradeNumber: grade,
    gradeCompletionPercent: gradeCompletion,
    attendanceRatePercent: attendanceRate,
    subjects: subjectSummaries,
    achievements,
    certificates: certificateTitles,
    upcomingSeminarTitles: sems.map((s) => s.title),
    pointsTotal: points.totalPoints,
    pointsLevel: points.level,
    pointsLevelTitleFa: points.levelTitleFa,
  });
});

export default parents;
// (audit wiring v1 — بخش ۲۰.۳)
