import 'package:equatable/equatable.dart';

/// یک ردیف فهرست رویدادهای «میدان ستارگان» — طبق
/// `GET /admin/live-arena/events` (`backend/src/routes/liveArena.ts`).
/// برخلاف `ArenaEventSummary` سمت شاگرد (`live_arena/domain/entities`)،
/// این نسخه برای پنل مدیر است: نام قهرمان و شمار شرکت‌کنندگان را هم دارد
/// (Join سمت سرور) تا صفحهٔ زمان‌بندی نیازی به درخواست‌های جداگانه نداشته
/// باشد.
class ArenaEventListItem extends Equatable {
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
  final String? championName;
  final int participantCount;

  const ArenaEventListItem({
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
    required this.championName,
    required this.participantCount,
  });

  bool get isLive => status == 'live';
  bool get isScheduled => status == 'scheduled';
  bool get isEnded => status == 'ended';

  factory ArenaEventListItem.fromJson(Map<String, dynamic> j) => ArenaEventListItem(
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
        championName: (j['championName'] as String?)?.trim().isNotEmpty == true ? j['championName'] as String : null,
        participantCount: (j['participantCount'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [id, status, startsAt];
}

/// پاسخ کامل `GET /admin/live-arena/events`.
class AdminArenaEventsPage extends Equatable {
  final List<ArenaEventListItem> events;
  final int questionBankCount;

  const AdminArenaEventsPage({required this.events, required this.questionBankCount});

  factory AdminArenaEventsPage.fromJson(Map<String, dynamic> j) => AdminArenaEventsPage(
        events: ((j['events'] as List?) ?? const [])
            .map((e) => ArenaEventListItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        questionBankCount: (j['questionBankCount'] as num?)?.toInt() ?? 0,
      );

  @override
  List<Object?> get props => [events, questionBankCount];
}
