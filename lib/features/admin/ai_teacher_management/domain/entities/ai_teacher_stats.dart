import 'package:equatable/equatable.dart';

/// شمار پیام‌های معلم هوشمند برای یک مضمون — برای نمودار «پرکاربردترین
/// مضمون‌ها» در پنل «مدیریت معلم هوشمند».
class AiTeacherSubjectUsage extends Equatable {
  final String subjectId;
  final String subjectNameFa;
  final int messageCount;

  const AiTeacherSubjectUsage({
    required this.subjectId,
    required this.subjectNameFa,
    required this.messageCount,
  });

  @override
  List<Object?> get props => [subjectId, messageCount];
}

/// آمار حقیقی استفاده از معلم هوشمند — طبق درخواست صریح مدیر: این بخش قبلاً
/// اصلاً فیلد آماری نداشت (نه واقعی، نه ساختگی). این آمار مستقیماً از لاگ
/// واقعی گفتگوهایی که از موتور ابری پاسخ گرفته‌اند محاسبه می‌شود — اگر هنوز
/// گفتگویی رخ نداده، همه‌چیز صفر است (هرگز عدد نمایشیِ فرضی نیست).
class AiTeacherStats extends Equatable {
  final int totalMessages;
  final int messagesToday;
  final int activeStudentsToday;
  final int activeStudentsWeek;

  /// درصد دقت پاسخ‌های شاگردان (حلقهٔ یادگیری تطبیقی) — `null` یعنی هنوز
  /// هیچ پاسخی ارزیابی نشده (نه صفر، چون صفر یعنی «همه غلط»).
  final double? accuracyPercent;
  final int totalAnsweredAttempts;

  /// چند درصد درس‌های منتشرشده Embedding دارند (بازیابی معنایی) — `null`
  /// یعنی هنوز هیچ درسی منتشر نشده.
  final double? embeddingCoveragePercent;

  final List<AiTeacherSubjectUsage> bySubject;

  const AiTeacherStats({
    required this.totalMessages,
    required this.messagesToday,
    required this.activeStudentsToday,
    required this.activeStudentsWeek,
    required this.bySubject,
    this.accuracyPercent,
    this.totalAnsweredAttempts = 0,
    this.embeddingCoveragePercent,
  });

  static const empty = AiTeacherStats(
    totalMessages: 0,
    messagesToday: 0,
    activeStudentsToday: 0,
    activeStudentsWeek: 0,
    bySubject: [],
  );

  @override
  List<Object?> get props => [
        totalMessages,
        messagesToday,
        activeStudentsToday,
        activeStudentsWeek,
        accuracyPercent,
        totalAnsweredAttempts,
        embeddingCoveragePercent,
        bySubject,
      ];
}
