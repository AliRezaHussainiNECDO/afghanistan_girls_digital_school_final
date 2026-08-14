/**
 * lib/liveArena.ts — لایهٔ دسترسی داده (D1) برای «آرنای زنده». تمام منطق
 * زمان‌بندی/real-time واقعی در Durable Object (`liveArenaRoom.ts`) است؛ این
 * فایل فقط خواندن/نوشتن دیتابیس را انجام می‌دهد — دقیقاً هم‌الگو با
 * `competition.ts` — تا هم از routes/liveArena.ts (HTTP) و هم از خودِ
 * Durable Object (که به همان DB بایند دسترسی دارد) قابل استفاده باشد.
 */
import { awardSafe, getCompetitionStatus, type RankTier } from './competition';

export type ArenaEventRow = {
  id: string;
  title_fa: string;
  starts_at: string;
  ends_at: string;
  status: 'scheduled' | 'live' | 'ended';
  min_rank_no: number;
  question_count: number;
  time_limit_seconds: number;
  champion_student_id: string | null;
  champion_points: number | null;
};

export type ArenaQuestionFull = {
  id: string;
  seq: number;
  promptFa: string;
  promptEn: string;
  promptPs: string;
  promptFr: string;
  optionsFa: string[];
  optionsEn: string[];
  optionsPs: string[];
  optionsFr: string[];
  correctIndex: number;
  points: number;
};

export type ArenaStanding = {
  position: number;
  studentId: string;
  displayName: string;
  avatarUrl: string | null;
  score: number;
  correctCount: number;
};

/** نزدیک‌ترین رویداد «برنامه‌ریزی‌شده» یا «در حال برگزاری» — برای نمایش در
 * صفحهٔ رقابت (بنر «آرنای زنده») و اتصال WebSocket. اگر هیچ‌کدام نبود، آخرین
 * رویداد «پایان‌یافته» را برمی‌گرداند (برای نمایش نتایج/قهرمان هفتهٔ قبل). */
export async function getCurrentOrLatestArenaEvent(db: D1Database): Promise<ArenaEventRow | null> {
  const upcoming = await db
    .prepare(`SELECT * FROM arena_events WHERE status IN ('scheduled','live') ORDER BY starts_at ASC LIMIT 1`)
    .first<ArenaEventRow>();
  if (upcoming) return upcoming;
  const past = await db.prepare(`SELECT * FROM arena_events WHERE status = 'ended' ORDER BY ends_at DESC LIMIT 1`).first<ArenaEventRow>();
  return past ?? null;
}

export async function getArenaEventById(db: D1Database, eventId: string): Promise<ArenaEventRow | null> {
  return db.prepare('SELECT * FROM arena_events WHERE id = ?').bind(eventId).first<ArenaEventRow>();
}

/** آیا این شاگرد واجد‌شرایط این رویداد است؟ (بر اساس مقام فعلی‌اش در سیستم ۵۰
 * مقام — همان چیزی که رویداد به‌عنوان `min_rank_no` می‌خواهد.) */
export async function checkEligibility(
  db: D1Database,
  studentId: string,
  event: ArenaEventRow,
): Promise<{ eligible: boolean; myRankNo: number }> {
  const status = await getCompetitionStatus(db, studentId);
  return { eligible: status.tier.rankNo >= event.min_rank_no, myRankNo: status.tier.rankNo };
}

/** فهرست کامل سؤال‌های یک رویداد (به‌ترتیب seq)، شامل پاسخ درست — فقط برای
 * مصرف سمت سرور (Durable Object). هرگز مستقیم به کلاینت فرستاده نشود. */
export async function getEventQuestionsFull(db: D1Database, eventId: string): Promise<ArenaQuestionFull[]> {
  const { results } = await db
    .prepare(
      `SELECT eq.seq, qb.id, qb.prompt_fa, qb.prompt_en, qb.prompt_ps, qb.prompt_fr,
              qb.options_fa, qb.options_en, qb.options_ps, qb.options_fr, qb.correct_index, qb.points
         FROM arena_event_questions eq
         JOIN arena_question_bank qb ON qb.id = eq.question_id
        WHERE eq.event_id = ?
        ORDER BY eq.seq ASC`,
    )
    .bind(eventId)
    .all<{
      seq: number;
      id: string;
      prompt_fa: string;
      prompt_en: string;
      prompt_ps: string;
      prompt_fr: string;
      options_fa: string;
      options_en: string;
      options_ps: string;
      options_fr: string;
      correct_index: number;
      points: number;
    }>();
  return results.map((r) => ({
    id: r.id,
    seq: r.seq,
    promptFa: r.prompt_fa,
    promptEn: r.prompt_en,
    promptPs: r.prompt_ps,
    promptFr: r.prompt_fr,
    optionsFa: JSON.parse(r.options_fa),
    optionsEn: JSON.parse(r.options_en),
    optionsPs: JSON.parse(r.options_ps),
    optionsFr: JSON.parse(r.options_fr),
    correctIndex: r.correct_index,
    points: r.points,
  }));
}

/** ثبت/به‌روزرسانی حضور شاگرد در رویداد (idempotent). */
export async function ensureParticipant(db: D1Database, eventId: string, studentId: string): Promise<void> {
  await db
    .prepare(`INSERT INTO arena_participants (event_id, student_id) VALUES (?, ?) ON CONFLICT(event_id, student_id) DO NOTHING`)
    .bind(eventId, studentId)
    .run();
}

/** ثبت یک پاسخ — fail-safe در برابر پاسخ تکراری (قید UNIQUE در دیتابیس آن را
 * رد می‌کند؛ اینجا فقط با try/catch بی‌صدا می‌بلعیم چون Durable Object قبل از
 * این تماس هم خودش پاسخ تکراری در حافظه را رد می‌کند — این لایهٔ دوم دفاعی
 * است، نه مسیر اصلی). امتیاز = امتیاز سؤال × ضریب سرعت (پاسخ سریع‌تر، امتیاز
 * بیشتر، حداقل ۴۰٪ امتیاز پایه برای پاسخ درست در آخرین لحظه). */
export async function recordAnswer(
  db: D1Database,
  eventId: string,
  studentId: string,
  question: ArenaQuestionFull,
  choiceIndex: number,
  msTaken: number,
  timeLimitMs: number,
): Promise<{ correct: boolean; pointsAwarded: number } | null> {
  const correct = choiceIndex === question.correctIndex;
  let pointsAwarded = 0;
  if (correct) {
    const speedFactor = Math.max(0.4, 1 - msTaken / Math.max(timeLimitMs, 1));
    pointsAwarded = Math.round(question.points * (0.4 + 0.6 * speedFactor));
  }
  try {
    await db
      .prepare(
        `INSERT INTO arena_answer_log (id, event_id, student_id, question_id, choice_index, correct, ms_taken)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .bind(`aal_${crypto.randomUUID()}`, eventId, studentId, question.id, choiceIndex, correct ? 1 : 0, msTaken)
      .run();
  } catch {
    return null; // پاسخ تکراری — نادیده گرفته می‌شود
  }
  await db
    .prepare(
      `UPDATE arena_participants
          SET score = score + ?, correct_count = correct_count + ?, last_answer_at = datetime('now')
        WHERE event_id = ? AND student_id = ?`,
    )
    .bind(pointsAwarded, correct ? 1 : 0, eventId, studentId)
    .run();
  return { correct, pointsAwarded };
}

export async function getStandings(db: D1Database, eventId: string, limit = 50): Promise<ArenaStanding[]> {
  const { results } = await db
    .prepare(
      `SELECT p.student_id, p.score, p.correct_count, u.first_name, u.last_name, u.avatar_url
         FROM arena_participants p JOIN users u ON u.id = p.student_id
        WHERE p.event_id = ?
        ORDER BY p.score DESC, p.last_answer_at ASC
        LIMIT ?`,
    )
    .bind(eventId, limit)
    .all<{ student_id: string; score: number; correct_count: number; first_name: string; last_name: string; avatar_url: string | null }>();
  return results.map((r, idx) => ({
    position: idx + 1,
    studentId: r.student_id,
    displayName: `${r.first_name} ${r.last_name}`.trim(),
    avatarUrl: r.avatar_url,
    score: r.score,
    correctCount: r.correct_count,
  }));
}

/** پایان رویداد: قهرمان را ثبت، وضعیت را «پایان‌یافته» می‌کند، و امتیاز
 * می‌دهد — به قهرمان پاداش بزرگ، به هر شرکت‌کننده پاداش کوچک مشارکت — که هر
 * دو مستقیم وارد `student_points_ledger` می‌شوند و روی سیستم ۵۰ مقامِ اصلی هم
 * اثر می‌گذارند (آرنا بخشی از همان رقابت است، نه جدا). fail-safe (هرگز
 * استثنا پرتاب نمی‌کند) — طبق الگوی awardSafe در competition.ts. */
export async function finalizeArenaEvent(db: D1Database, eventId: string): Promise<void> {
  try {
    const standings = await getStandings(db, eventId, 1000);
    const champion = standings[0] ?? null;
    await db
      .prepare(`UPDATE arena_events SET status = 'ended', champion_student_id = ?, champion_points = ? WHERE id = ?`)
      .bind(champion?.studentId ?? null, champion?.score ?? null, eventId)
      .run();
    for (const [idx, s] of standings.entries()) {
      const bonus = idx === 0 ? 300 : idx < 3 ? 150 : 20; // قهرمان، نفر دوم/سوم، بقیهٔ شرکت‌کنندگان
      await awardSafe(db, s.studentId, bonus, idx === 0 ? 'live_arena_champion' : 'live_arena_participation', eventId);
    }
  } catch (err) {
    console.error(`[finalizeArenaEvent:${eventId}] fail-safe —`, err);
  }
}

/** فراخوانی از کرون (index.ts): رویدادهای رسیده به زمان شروع را «زنده» علامت
 * می‌زند (شروع واقعیِ چرخهٔ سؤال بر عهدهٔ خودِ Durable Object است — این تابع
 * فقط به آن سیگنال می‌دهد)، و رویدادهایی که زمان پایانشان گذشته ولی هنوز
 * توسط DO پایان‌یافته علامت نخورده‌اند را به‌عنوان اقدام پشتیبان (اگر DO به
 * هر دلیلی از کار افتاده بود) خودش پایان می‌دهد. */
export async function transitionArenaEvents(
  db: D1Database,
  startRoom: (eventId: string) => Promise<void>,
): Promise<void> {
  const { results: toStart } = await db
    .prepare(`SELECT id FROM arena_events WHERE status = 'scheduled' AND starts_at <= datetime('now')`)
    .all<{ id: string }>();
  for (const row of toStart) {
    await db.prepare(`UPDATE arena_events SET status = 'live' WHERE id = ?`).bind(row.id).run();
    try {
      await startRoom(row.id);
    } catch (err) {
      console.error(`[transitionArenaEvents:start:${row.id}] —`, err);
    }
  }

  // پشتیبان: اگر یک رویداد خیلی از زمان پایانش گذشته (۲ برابر بازهٔ عادی) و
  // هنوز «زنده» مانده، یعنی DO به هر دلیلی خودش را پایان نداده — این‌جا با
  // زور آن را می‌بندیم تا شرکت‌کنندگان برای همیشه در حالت «در حال برگزاری» گیر نمانند.
  const { results: stale } = await db
    .prepare(`SELECT id FROM arena_events WHERE status = 'live' AND ends_at <= datetime('now', '-30 minutes')`)
    .all<{ id: string }>();
  for (const row of stale) {
    await finalizeArenaEvent(db, row.id);
  }
}

/** یک ردیف فهرست رویدادها برای پنل مدیر — شامل نام قهرمان (join با users) و
 * شمار شرکت‌کنندگان، تا صفحهٔ زمان‌بندی نیازی به درخواست‌های جداگانه نداشته
 * باشد. */
export type ArenaEventListRow = ArenaEventRow & {
  champion_first_name: string | null;
  champion_last_name: string | null;
  participant_count: number;
};

/** فهرست رویدادها (جدیدترین‌ها اول) — برای صفحهٔ «زمان‌بندی میدان ستارگان»
 * در پنل مدیر: هم رویداد جاری/بعدی، هم تاریخچهٔ رویدادهای پایان‌یافته. */
export async function listArenaEvents(db: D1Database, limit = 30): Promise<ArenaEventListRow[]> {
  const { results } = await db
    .prepare(
      `SELECT e.*, u.first_name AS champion_first_name, u.last_name AS champion_last_name,
              (SELECT COUNT(*) FROM arena_participants p WHERE p.event_id = e.id) AS participant_count
         FROM arena_events e
         LEFT JOIN users u ON u.id = e.champion_student_id
        ORDER BY e.starts_at DESC
        LIMIT ?`,
    )
    .bind(limit)
    .all<ArenaEventListRow>();
  return results;
}

/** شمار سؤال‌های فعال بانک — تا فرم زمان‌بندی بتواند هشدار بدهد اگر
 * `questionCount` درخواستی بیشتر از موجودی بانک باشد. */
export async function getActiveQuestionBankCount(db: D1Database): Promise<number> {
  const row = await db.prepare(`SELECT COUNT(*) AS c FROM arena_question_bank WHERE active = 1`).first<{ c: number }>();
  return row?.c ?? 0;
}

/** لغو یک رویداد «برنامه‌ریزی‌شده» (هنوز شروع نشده) — مثلاً مدیر می‌خواهد
 * زمان/تنظیمات را عوض کند. عمداً فقط `status = 'scheduled'` مجاز است:
 * رویدادهای «در حال برگزاری»/«پایان‌یافته» هرگز قابل لغو نیستند، چون
 * شرکت‌کننده‌ای که وسط مسابقهٔ زنده است نباید ناگهان غافلگیر شود. برمی‌گرداند
 * که آیا واقعاً لغو شد (false یعنی یافت نشد یا دیگر scheduled نبود). */
export async function cancelScheduledEvent(db: D1Database, eventId: string): Promise<boolean> {
  const event = await getArenaEventById(db, eventId);
  if (!event || event.status !== 'scheduled') return false;
  await db.prepare(`DELETE FROM arena_event_questions WHERE event_id = ?`).bind(eventId).run();
  await db.prepare(`DELETE FROM arena_events WHERE id = ?`).bind(eventId).run();
  return true;
}
