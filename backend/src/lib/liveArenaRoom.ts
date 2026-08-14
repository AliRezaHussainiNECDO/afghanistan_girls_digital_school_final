/**
 * lib/liveArenaRoom.ts — Durable Object «اتاق آرنای زنده». یک نمونه از این
 * کلاس به‌ازای هر `arena_events.id` ساخته می‌شود (نگاه کن به
 * `routes/liveArena.ts`: `env.LIVE_ARENA_ROOM.idFromName(eventId)`).
 *
 * چرا Durable Object (نه فقط WebSocket ساده در Worker)؟ چون همهٔ
 * شرکت‌کنندگان یک رویداد باید دقیقاً یک «منبع حقیقت» مشترک ببینند (کدام
 * سؤال الان است، چقدر زمان مانده، جدول امتیاز لحظه‌ای) — یک Durable Object
 * تنها نمونهٔ در حالِ اجرای خودش را در کل دنیا تضمین می‌کند، پس broadcast
 * بین چند اتصال هم‌زمان بدون نیاز به Redis/PubSub بیرونی ساده است.
 *
 * از WebSocket Hibernation API استفاده شده (`state.acceptWebSocket` +
 * `webSocketMessage`/`webSocketClose` به‌جای یک حلقهٔ `addEventListener` که
 * دائم در حافظه نگه داشته شود) — یعنی بین سؤال‌ها (وقتی هیچ پیامی رد و بدل
 * نمی‌شود) Durable Object می‌تواند از حافظه خارج (hibernate) شود و هزینه‌ای
 * ندارد، ولی اتصال کلاینت باز می‌ماند و با پیام بعدی خودش بیدار می‌شود.
 *
 * زمان‌بندی هر سؤال با Alarm انجام می‌شود (نه تایمر سمت کلاینت) — یعنی حتی
 * اگر کلاینت ساعتش را دستکاری کند، تشخیص «وقت تمام شد» و رفتن به سؤال بعدی
 * کاملاً سمت سرور است.
 */
import { getArenaEventById, getEventQuestionsFull, ensureParticipant, recordAnswer, getStandings, finalizeArenaEvent, type ArenaQuestionFull } from './liveArena';

type Bindings = { DB: D1Database; JWT_SECRET: string };

type RoomPhase = 'waiting' | 'question' | 'reveal' | 'finished';

type RoomState = {
  eventId: string;
  phase: RoomPhase;
  questionIndex: number; // -1 قبل از شروع
  questionEndsAt: string | null; // ISO — پایان پنجرهٔ پاسخ‌دهی سؤال جاری
  revealEndsAt: string | null; // ISO — چند ثانیه نمایش پاسخ درست قبل از سؤال بعدی
};

type WsAttachment = { studentId: string; displayName: string };

const REVEAL_MS = 4000; // چند ثانیه پاسخ درست + جدول لحظه‌ای نمایش داده شود

export class LiveArenaRoom {
  state: DurableObjectState;
  env: Bindings;
  private questions: ArenaQuestionFull[] | null = null;

  constructor(state: DurableObjectState, env: Bindings) {
    this.state = state;
    this.env = env;
  }

  private async getRoomState(): Promise<RoomState | null> {
    return (await this.state.storage.get<RoomState>('room')) ?? null;
  }

  private async setRoomState(s: RoomState): Promise<void> {
    await this.state.storage.put('room', s);
  }

  private async loadQuestions(eventId: string): Promise<ArenaQuestionFull[]> {
    if (this.questions) return this.questions;
    const cached = await this.state.storage.get<ArenaQuestionFull[]>('questions');
    if (cached) {
      this.questions = cached;
      return cached;
    }
    const qs = await getEventQuestionsFull(this.env.DB, eventId);
    await this.state.storage.put('questions', qs);
    this.questions = qs;
    return qs;
  }

  /** پیامی که برای کلاینت‌ها فرستاده می‌شود — هرگز شامل `correctIndex` سؤال
   * جاری نیست (فقط در فاز reveal، بعد از بسته‌شدن پنجرهٔ پاسخ‌دهی، فاش می‌شود). */
  private async publicSnapshot(): Promise<Record<string, unknown>> {
    const room = await this.getRoomState();
    if (!room) return { type: 'snapshot', phase: 'waiting', questionIndex: -1 };
    const event = await getArenaEventById(this.env.DB, room.eventId);
    const standings = await getStandings(this.env.DB, room.eventId, 10);
    const base = {
      type: 'snapshot',
      phase: room.phase,
      questionIndex: room.questionIndex,
      totalQuestions: event?.question_count ?? 0,
      timeLimitSeconds: event?.time_limit_seconds ?? 15,
      questionEndsAt: room.questionEndsAt,
      revealEndsAt: room.revealEndsAt,
      standings,
    };
    if (room.phase === 'question' || room.phase === 'reveal') {
      const qs = await this.loadQuestions(room.eventId);
      const q = qs[room.questionIndex];
      if (q) {
        return {
          ...base,
          question: {
            id: q.id,
            promptFa: q.promptFa,
            promptEn: q.promptEn,
            promptPs: q.promptPs,
            promptFr: q.promptFr,
            optionsFa: q.optionsFa,
            optionsEn: q.optionsEn,
            optionsPs: q.optionsPs,
            optionsFr: q.optionsFr,
            // پاسخ درست فقط در فاز reveal فاش می‌شود:
            correctIndex: room.phase === 'reveal' ? q.correctIndex : null,
          },
        };
      }
    }
    return base;
  }

  private broadcast(payload: Record<string, unknown>): void {
    const msg = JSON.stringify(payload);
    for (const ws of this.state.getWebSockets()) {
      try {
        ws.send(msg);
      } catch {
        // اتصال مرده — نادیده گرفته می‌شود، خودش با webSocketClose پاک می‌شود
      }
    }
  }

  /** درخواست HTTP معمولی (نه WebSocket) — یا شروع رویداد (از کرون) یا Upgrade اتصال زنده. */
  async fetch(request: Request): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname.endsWith('/start')) {
      const eventId = url.searchParams.get('eventId');
      if (!eventId) return new Response('missing eventId', { status: 400 });
      await this.beginEvent(eventId);
      return new Response('started', { status: 200 });
    }

    if (request.headers.get('Upgrade') !== 'websocket') {
      return new Response('expected websocket', { status: 426 });
    }

    const studentId = url.searchParams.get('studentId');
    const displayName = url.searchParams.get('displayName') ?? '';
    const eventId = url.searchParams.get('eventId');
    if (!studentId || !eventId) return new Response('missing studentId/eventId', { status: 400 });

    await ensureParticipant(this.env.DB, eventId, studentId);

    const pair = new WebSocketPair();
    const [client, server] = Object.values(pair);
    this.state.acceptWebSocket(server, [studentId]);
    const attachment: WsAttachment = { studentId, displayName };
    server.serializeAttachment(attachment);

    const snapshot = await this.publicSnapshot();
    server.send(JSON.stringify(snapshot));
    this.broadcast({ type: 'presence', participantCount: this.state.getWebSockets().length });

    return new Response(null, { status: 101, webSocket: client });
  }

  /** شروع چرخهٔ رویداد — یک‌بار، وقتی کرون (`transitionArenaEvents`) به این
   * DO سیگنال می‌دهد که `starts_at` رسیده است. */
  private async beginEvent(eventId: string): Promise<void> {
    const existing = await this.getRoomState();
    if (existing) return; // قبلاً شروع شده — idempotent
    await this.setRoomState({ eventId, phase: 'waiting', questionIndex: -1, questionEndsAt: null, revealEndsAt: null });
    await this.advanceToNextQuestion();
  }

  private async advanceToNextQuestion(): Promise<void> {
    const room = await this.getRoomState();
    if (!room) return;
    const event = await getArenaEventById(this.env.DB, room.eventId);
    if (!event) return;
    const questions = await this.loadQuestions(room.eventId);
    const nextIndex = room.questionIndex + 1;

    if (nextIndex >= questions.length) {
      await this.finish(room.eventId);
      return;
    }

    const endsAt = new Date(Date.now() + event.time_limit_seconds * 1000).toISOString();
    await this.setRoomState({ ...room, phase: 'question', questionIndex: nextIndex, questionEndsAt: endsAt, revealEndsAt: null });
    await this.state.storage.setAlarm(Date.now() + event.time_limit_seconds * 1000);
    this.broadcast(await this.publicSnapshot());
  }

  private async revealCurrentQuestion(): Promise<void> {
    const room = await this.getRoomState();
    if (!room) return;
    const revealEndsAt = new Date(Date.now() + REVEAL_MS).toISOString();
    await this.setRoomState({ ...room, phase: 'reveal', questionEndsAt: null, revealEndsAt });
    await this.state.storage.setAlarm(Date.now() + REVEAL_MS);
    this.broadcast(await this.publicSnapshot());
  }

  private async finish(eventId: string): Promise<void> {
    const room = await this.getRoomState();
    if (room) await this.setRoomState({ ...room, phase: 'finished', questionEndsAt: null, revealEndsAt: null });
    await finalizeArenaEvent(this.env.DB, eventId);
    this.broadcast(await this.publicSnapshot());
  }

  /** Alarm سمت سرور — پنجرهٔ پاسخ‌دهی سؤال جاری (یا نمایش پاسخ) تمام شده. */
  async alarm(): Promise<void> {
    const room = await this.getRoomState();
    if (!room) return;
    if (room.phase === 'question') {
      await this.revealCurrentQuestion();
    } else if (room.phase === 'reveal') {
      await this.advanceToNextQuestion();
    }
  }

  /** پیام ورودی از یک شاگرد — فقط نوع `answer` پذیرفته می‌شود. */
  async webSocketMessage(ws: WebSocket, message: string): Promise<void> {
    let parsed: { type?: string; choiceIndex?: number } = {};
    try {
      parsed = JSON.parse(message);
    } catch {
      return;
    }
    if (parsed.type !== 'answer' || typeof parsed.choiceIndex !== 'number') return;

    const room = await this.getRoomState();
    if (!room || room.phase !== 'question') return;
    const attachment = ws.deserializeAttachment() as WsAttachment | null;
    if (!attachment) return;

    const questions = await this.loadQuestions(room.eventId);
    const question = questions[room.questionIndex];
    if (!question) return;

    const event = await getArenaEventById(this.env.DB, room.eventId);
    const timeLimitMs = (event?.time_limit_seconds ?? 15) * 1000;
    const questionStartedAt = room.questionEndsAt ? new Date(room.questionEndsAt).getTime() - timeLimitMs : Date.now();
    const msTaken = Math.max(0, Date.now() - questionStartedAt);

    const result = await recordAnswer(this.env.DB, room.eventId, attachment.studentId, question, parsed.choiceIndex, msTaken, timeLimitMs);
    if (result) {
      ws.send(JSON.stringify({ type: 'answerAck', correct: result.correct, pointsAwarded: result.pointsAwarded }));
    }
  }

  async webSocketClose(ws: WebSocket, _code: number, _reason: string, _wasClean: boolean): Promise<void> {
    try {
      ws.close();
    } catch {
      /* noop */
    }
    this.broadcast({ type: 'presence', participantCount: Math.max(0, this.state.getWebSockets().length - 1) });
  }

  async webSocketError(_ws: WebSocket, _error: unknown): Promise<void> {
    // Hibernation API نیازمند این متد است؛ خطاها همان‌طور که close هم فرا
    // خوانده می‌شود مدیریت می‌شوند — اینجا کاری لازم نیست.
  }
}
