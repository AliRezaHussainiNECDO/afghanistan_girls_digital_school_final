import 'package:equatable/equatable.dart';

/// یک مضمونِ «در حال انجام» که شاگرد می‌تواند از همان‌جا که رها کرده ادامه
/// دهد — چند مورد از این در خانهٔ شاگرد نمایش داده می‌شود (نه فقط یک مضمون).
class ContinueLearningItem extends Equatable {
  final String subjectId;
  final String subjectNameFa;
  final String lessonTitle;
  final double progressPercent;

  const ContinueLearningItem({
    required this.subjectId,
    required this.subjectNameFa,
    required this.lessonTitle,
    required this.progressPercent,
  });

  @override
  List<Object?> get props => [subjectId, lessonTitle, progressPercent];
}

/// یک سمینار پیش‌رو برای نمای خانهٔ شاگرد — رفع اشکال: قبلاً سرور/کلاینت
/// فقط «نزدیک‌ترین یک سمینار» را نگه می‌داشتند (`upcomingSeminarTitle`/
/// `upcomingSeminarDate` تکی)، در حالی که ممکن بود چند سمینار در انتظار
/// باشند و شاگرد فقط یکی از آن‌ها را در خانه می‌دید. اکنون فهرستی از
/// سمینارهای در انتظار (طبق همان قاعدهٔ بخش ۱۲.۲: منتشرشده/زنده و
/// پایان‌نیافته) نمایش داده می‌شود.
class UpcomingSeminarPreview extends Equatable {
  final String title;
  final DateTime scheduledStart;
  const UpcomingSeminarPreview({required this.title, required this.scheduledStart});

  @override
  List<Object?> get props => [title, scheduledStart];
}

/// خلاصهٔ داشبورد دانش‌آموز — تجمیع چند سیگنال برای نمایش سریع در خانه
/// (بخش ۵.۵ توصیه‌ها + بخش ۶ پیشرفت + بخش ۷ امتحان + بخش ۱۲ سمینار).
class DashboardSummary extends Equatable {
  final String studentDisplayName;
  final double overallProgressPercent;
  final String currentLessonTitle;
  final String currentSubjectNameFa;

  /// فهرست چندمضمونی «ادامهٔ یادگیری» (منبع: `dashboard-summary` سرور) —
  /// به‌جای نمایش فقط یک مضمون ثابت، تا ۳ موردی که شاگرد واقعاً در آن‌ها
  /// فعالیت داشته و هنوز تکمیل نشده، به ترتیب آخرین بازدید.
  final List<ContinueLearningItem> continueLearning;

  final String? upcomingExamTitle;
  final DateTime? upcomingExamDate;

  /// فهرست سمینارهای در انتظار (حداکثر چند مورد نزدیک‌تر) — رجوع کنید به
  /// مستندِ [UpcomingSeminarPreview] برای رفع اشکال «فقط یک سمینار».
  final List<UpcomingSeminarPreview> upcomingSeminars;
  final List<String> recommendedTopics; // طبق بخش ۵.۵ — نقاط ضعف فعال

  /// امتیاز فعالیت (Gamification) — طبق `backend/src/lib/progress.ts`
  /// `getPointsSummary`؛ همین سه فیلد در داشبورد والدین هم نمایش داده
  /// می‌شود تا منطق امتیازدهی در همه‌جا یکسان باشد.
  final int pointsTotal;
  final int pointsLevel;
  final String pointsLevelTitleFa;

  /// رفع اشکال: سرور این سه مقدار را از قبل محاسبه می‌کرد (`getPointsSummary`)
  /// ولی Endpoint خلاصهٔ داشبورد هرگز آن‌ها را نمی‌فرستاد — یعنی خانهٔ شاگرد
  /// نمی‌توانست نوار «چند امتیاز تا سطح بعدی» را نشان بدهد. `null` یعنی
  /// شاگرد در بالاترین سطح است (سطح بعدی وجود ندارد).
  final int? pointsNextLevelAt;
  final String? pointsNextLevelTitleFa;
  final double pointsProgressToNextPercent;

  /// تعداد گواهی‌نامه‌های صادرشده — تا کارت «گواهی‌نامه‌های من» در خانهٔ
  /// شاگرد وضعیت واقعی را نشان دهد نه یک متن ثابت.
  final int certificatesCount;

  const DashboardSummary({
    required this.studentDisplayName,
    required this.overallProgressPercent,
    required this.currentLessonTitle,
    required this.currentSubjectNameFa,
    this.continueLearning = const [],
    this.upcomingExamTitle,
    this.upcomingExamDate,
    this.upcomingSeminars = const [],
    this.recommendedTopics = const [],
    this.pointsTotal = 0,
    this.pointsLevel = 1,
    this.pointsLevelTitleFa = 'نوآموز',
    this.pointsNextLevelAt,
    this.pointsNextLevelTitleFa,
    this.pointsProgressToNextPercent = 0,
    this.certificatesCount = 0,
  });

  @override
  List<Object?> get props => [studentDisplayName, overallProgressPercent];
}
