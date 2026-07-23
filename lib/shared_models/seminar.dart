import 'package:equatable/equatable.dart';

/// طبق بخش ۱۲ و ۱۷.۷ سند (`seminars`).
enum SeminarStatus { draft, published, registrationClosed, live, ended, archived }

/// مخاطب سمینار — شاگردان یا والدین (طبق بخش ۱۳ب: سمینارهای مخصوص والدین).
enum SeminarAudience { students, parents }

class Seminar extends Equatable {
  final String id;
  final String title;
  final String description;
  final String instructorId;
  final String instructorName;
  final DateTime scheduledStart;
  final int durationMinutes;
  final SeminarStatus status;
  final int? capacity;
  final SeminarAudience audience;

  /// لینک جلسهٔ زندهٔ خارجی (Zoom/Google Meet/Jitsi) — بخش ۱۲ سند. در زمان
  /// سمینار، دکمهٔ «پیوستن به جلسهٔ زنده» این آدرس را باز می‌کند.
  final String meetingLink;

  /// شناسهٔ ورودیِ زندهٔ Cloudflare Stream (در صورت فعال بودن پخش زنده).
  final String streamUid;

  /// نشانی پخش زندهٔ HLS برای شاگردان (خروجی Cloudflare Stream). اگر خالی
  /// باشد یعنی استاد هنوز پخش زنده را شروع نکرده است.
  final String streamPlaybackUrl;

  /// نشانی پخش زندهٔ MPEG-DASH (جایگزین HLS برای پخش‌کننده‌های سازگار با DASH).
  final String streamDashUrl;

  /// شناسهٔ کاربرانی که ثبت‌نام کرده‌اند — تضمین «فقط یک‌بار ثبت‌نام».
  final Set<String> registeredUserIds;

  /// گزارش خلاصهٔ تولیدشده با هوش مصنوعی — فقط بعد از آرشیف خودکار روی
  /// سرور (`status == archived`) مقدار واقعی دارد؛ پیش از آن خالی است.
  final String aiReportFa;

  /// زمان آرشیف‌شدن — برای مرتب‌سازی/نمایش در تب «آرشیف».
  final DateTime? archivedAt;

  const Seminar({
    required this.id,
    required this.title,
    this.description = '',
    this.instructorId = '',
    required this.instructorName,
    required this.scheduledStart,
    required this.durationMinutes,
    required this.status,
    this.capacity,
    this.audience = SeminarAudience.students,
    this.meetingLink = '',
    this.streamUid = '',
    this.streamPlaybackUrl = '',
    this.streamDashUrl = '',
    this.registeredUserIds = const {},
    this.aiReportFa = '',
    this.archivedAt,
  });

  /// آیا لینک جلسهٔ زندهٔ معتبری ثبت شده است؟
  bool get hasMeetingLink => meetingLink.trim().isNotEmpty;

  /// آیا پخش زندهٔ Cloudflare Stream فعال است؟
  bool get hasLiveStream => streamPlaybackUrl.trim().isNotEmpty;

  int get registeredCount => registeredUserIds.length;

  DateTime get scheduledEnd => scheduledStart.add(Duration(minutes: durationMinutes));

  bool get isFull => capacity != null && registeredCount >= capacity!;

  bool isRegistered(String userId) => registeredUserIds.contains(userId);

  /// آیا الان در بازهٔ زمانی جلسه هستیم؟ (از ۱۰ دقیقه قبل از شروع تا پایان)
  bool get isWithinSessionWindow {
    final now = DateTime.now();
    return now.isAfter(scheduledStart.subtract(const Duration(minutes: 10))) &&
        now.isBefore(scheduledEnd);
  }

  /// وضعیت مؤثر: اگر سمینار منتشرشده و زمان جلسه رسیده باشد، «زنده» است
  /// حتی اگر استاد هنوز دکمهٔ شروع را نزده باشد (منطق بخش ۱۲.۲ State Machine).
  SeminarStatus get effectiveStatus {
    if (status == SeminarStatus.live) {
      return DateTime.now().isAfter(scheduledEnd) ? SeminarStatus.ended : SeminarStatus.live;
    }
    if (status == SeminarStatus.published || status == SeminarStatus.registrationClosed) {
      if (DateTime.now().isAfter(scheduledEnd)) return SeminarStatus.ended;
      if (isWithinSessionWindow) return SeminarStatus.live;
    }
    return status;
  }

  bool get isLiveNow => effectiveStatus == SeminarStatus.live;

  bool get hasEnded =>
      effectiveStatus == SeminarStatus.ended || effectiveStatus == SeminarStatus.archived;

  /// آیا این سمینار به آرشیف منتقل شده (با گزارش هوش مصنوعی همراه)؟
  bool get isArchived => status == SeminarStatus.archived;

  /// آیا ثبت‌نام باز است؟
  bool get isRegistrationOpen =>
      (status == SeminarStatus.published || status == SeminarStatus.live) && !hasEnded && !isFull;

  Seminar copyWith({
    String? title,
    String? description,
    String? instructorId,
    String? instructorName,
    DateTime? scheduledStart,
    int? durationMinutes,
    SeminarStatus? status,
    int? capacity,
    bool clearCapacity = false,
    SeminarAudience? audience,
    String? meetingLink,
    String? streamUid,
    String? streamPlaybackUrl,
    String? streamDashUrl,
    Set<String>? registeredUserIds,
    String? aiReportFa,
    DateTime? archivedAt,
  }) {
    return Seminar(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      instructorId: instructorId ?? this.instructorId,
      instructorName: instructorName ?? this.instructorName,
      scheduledStart: scheduledStart ?? this.scheduledStart,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      capacity: clearCapacity ? null : (capacity ?? this.capacity),
      audience: audience ?? this.audience,
      meetingLink: meetingLink ?? this.meetingLink,
      streamUid: streamUid ?? this.streamUid,
      streamPlaybackUrl: streamPlaybackUrl ?? this.streamPlaybackUrl,
      streamDashUrl: streamDashUrl ?? this.streamDashUrl,
      registeredUserIds: registeredUserIds ?? this.registeredUserIds,
      aiReportFa: aiReportFa ?? this.aiReportFa,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        scheduledStart,
        durationMinutes,
        status,
        capacity,
        audience,
        meetingLink,
        streamUid,
        streamPlaybackUrl,
        streamDashUrl,
        registeredUserIds,
        aiReportFa,
        archivedAt,
      ];
}
