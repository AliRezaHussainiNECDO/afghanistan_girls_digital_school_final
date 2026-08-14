import 'package:equatable/equatable.dart';

/// خلاصهٔ رویداد آرنا — طبق `GET /live-arena/current` (`event` در پاسخ).
class ArenaEventSummary extends Equatable {
  final String id;
  final String titleFa;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status; // scheduled|live|ended
  final int minRankNo;
  final int questionCount;
  final int timeLimitSeconds;
  final String? championStudentId;
  final int? championPoints;

  const ArenaEventSummary({
    required this.id,
    required this.titleFa,
    required this.startsAt,
    required this.endsAt,
    required this.status,
    required this.minRankNo,
    required this.questionCount,
    required this.timeLimitSeconds,
    required this.championStudentId,
    required this.championPoints,
  });

  bool get isLive => status == 'live';
  bool get isScheduled => status == 'scheduled';
  bool get isEnded => status == 'ended';

  factory ArenaEventSummary.fromJson(Map<String, dynamic> j) => ArenaEventSummary(
        id: j['id']?.toString() ?? '',
        titleFa: j['titleFa']?.toString() ?? '',
        startsAt: DateTime.tryParse(j['startsAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        endsAt: DateTime.tryParse(j['endsAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        status: j['status']?.toString() ?? 'scheduled',
        minRankNo: (j['minRankNo'] as num?)?.toInt() ?? 1,
        questionCount: (j['questionCount'] as num?)?.toInt() ?? 10,
        timeLimitSeconds: (j['timeLimitSeconds'] as num?)?.toInt() ?? 15,
        championStudentId: j['championStudentId']?.toString(),
        championPoints: (j['championPoints'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [id, status, startsAt];
}

/// پاسخ کامل `GET /live-arena/current` — رویداد (اگر باشد) + واجد‌شرایطی من.
class ArenaCurrentInfo extends Equatable {
  final ArenaEventSummary? event;
  final bool eligible;
  final int myRankNo;

  const ArenaCurrentInfo({required this.event, required this.eligible, required this.myRankNo});

  factory ArenaCurrentInfo.fromJson(Map<String, dynamic> j) => ArenaCurrentInfo(
        event: j['event'] == null ? null : ArenaEventSummary.fromJson(Map<String, dynamic>.from(j['event'] as Map)),
        eligible: j['eligible'] == true,
        myRankNo: (j['myRankNo'] as num?)?.toInt() ?? 1,
      );

  @override
  List<Object?> get props => [event, eligible, myRankNo];
}

/// یک ردیف جدول امتیاز لحظه‌ای (هم از WebSocket و هم از `/results`).
class ArenaStanding extends Equatable {
  final int position;
  final String studentId;
  final String displayName;
  final String? avatarUrl;
  final int score;
  final int correctCount;

  const ArenaStanding({
    required this.position,
    required this.studentId,
    required this.displayName,
    required this.avatarUrl,
    required this.score,
    required this.correctCount,
  });

  factory ArenaStanding.fromJson(Map<String, dynamic> j) => ArenaStanding(
        position: (j['position'] as num?)?.toInt() ?? 0,
        studentId: j['studentId']?.toString() ?? '',
        displayName: j['displayName']?.toString() ?? '',
        avatarUrl: j['avatarUrl']?.toString(),
        score: (j['score'] as num?)?.toInt() ?? 0,
        correctCount: (j['correctCount'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [studentId, score, position];
}

/// سؤالِ «قابل نمایش به کلاینت» — `correctIndex` فقط در فاز reveal پر می‌شود
/// (سرور تا قبل از آن آن را اصلاً نمی‌فرستد، `null` می‌ماند).
class ArenaQuestionPublic extends Equatable {
  final String id;
  final String promptFa, promptEn, promptPs, promptFr;
  final List<String> optionsFa, optionsEn, optionsPs, optionsFr;
  final int? correctIndex;

  const ArenaQuestionPublic({
    required this.id,
    required this.promptFa,
    required this.promptEn,
    required this.promptPs,
    required this.promptFr,
    required this.optionsFa,
    required this.optionsEn,
    required this.optionsPs,
    required this.optionsFr,
    required this.correctIndex,
  });

  factory ArenaQuestionPublic.fromJson(Map<String, dynamic> j) => ArenaQuestionPublic(
        id: j['id']?.toString() ?? '',
        promptFa: j['promptFa']?.toString() ?? '',
        promptEn: j['promptEn']?.toString() ?? '',
        promptPs: j['promptPs']?.toString() ?? '',
        promptFr: j['promptFr']?.toString() ?? '',
        optionsFa: List<String>.from(j['optionsFa'] as List? ?? const []),
        optionsEn: List<String>.from(j['optionsEn'] as List? ?? const []),
        optionsPs: List<String>.from(j['optionsPs'] as List? ?? const []),
        optionsFr: List<String>.from(j['optionsFr'] as List? ?? const []),
        correctIndex: (j['correctIndex'] as num?)?.toInt(),
      );

  @override
  List<Object?> get props => [id, correctIndex];
}

enum ArenaPhase { waiting, question, reveal, finished }

ArenaPhase arenaPhaseFromString(String? s) => switch (s) {
      'question' => ArenaPhase.question,
      'reveal' => ArenaPhase.reveal,
      'finished' => ArenaPhase.finished,
      _ => ArenaPhase.waiting,
    };

/// یک اسنپ‌شات کامل از وضعیت اتاق — هر پیام `type: 'snapshot'` از
/// Durable Object با این شکل parse می‌شود (نگاه کن به
/// `backend/src/lib/liveArenaRoom.ts::publicSnapshot`).
class ArenaRoomSnapshot extends Equatable {
  final ArenaPhase phase;
  final int questionIndex;
  final int totalQuestions;
  final int timeLimitSeconds;
  final DateTime? questionEndsAt;
  final DateTime? revealEndsAt;
  final List<ArenaStanding> standings;
  final ArenaQuestionPublic? question;

  const ArenaRoomSnapshot({
    required this.phase,
    required this.questionIndex,
    required this.totalQuestions,
    required this.timeLimitSeconds,
    required this.questionEndsAt,
    required this.revealEndsAt,
    required this.standings,
    required this.question,
  });

  factory ArenaRoomSnapshot.fromJson(Map<String, dynamic> j) => ArenaRoomSnapshot(
        phase: arenaPhaseFromString(j['phase']?.toString()),
        questionIndex: (j['questionIndex'] as num?)?.toInt() ?? -1,
        totalQuestions: (j['totalQuestions'] as num?)?.toInt() ?? 0,
        timeLimitSeconds: (j['timeLimitSeconds'] as num?)?.toInt() ?? 15,
        questionEndsAt: j['questionEndsAt'] == null ? null : DateTime.tryParse(j['questionEndsAt'].toString())?.toLocal(),
        revealEndsAt: j['revealEndsAt'] == null ? null : DateTime.tryParse(j['revealEndsAt'].toString())?.toLocal(),
        standings: ((j['standings'] as List?) ?? const [])
            .map((e) => ArenaStanding.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        question: j['question'] == null ? null : ArenaQuestionPublic.fromJson(Map<String, dynamic>.from(j['question'] as Map)),
      );

  @override
  List<Object?> get props => [phase, questionIndex, standings];
}

/// تأیید فوری بعد از ارسال پاسخ (`type: 'answerAck'`).
class ArenaAnswerAck extends Equatable {
  final bool correct;
  final int pointsAwarded;
  const ArenaAnswerAck({required this.correct, required this.pointsAwarded});

  factory ArenaAnswerAck.fromJson(Map<String, dynamic> j) =>
      ArenaAnswerAck(correct: j['correct'] == true, pointsAwarded: (j['pointsAwarded'] as num?)?.toInt() ?? 0);

  @override
  List<Object?> get props => [correct, pointsAwarded];
}
