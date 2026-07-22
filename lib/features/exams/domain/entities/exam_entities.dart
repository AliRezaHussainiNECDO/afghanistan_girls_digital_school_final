import 'package:equatable/equatable.dart';

/// طبق بخش ۷.۱ سند.
enum ExamType { dailyQuiz, homework, monthly, finalExam }

/// نوع سؤال — مطابق ستون `q_type` جدول واقعی `questions`
/// (backend/migrations/0030_question_types.sql):
///   mcq       چهارگزینه‌ای (رفتار قبلی)
///   trueFalse صحیح / غلط (دو گزینهٔ ثابت)
///   essay     تشریحی (شاگرد متن می‌نویسد؛ نمره‌دهی AI سمت سرور)
enum QuestionType { mcq, trueFalse, essay }

/// آستانهٔ قبولی امتحان — باید دقیقاً با ثابت سرور
/// (backend/src/lib/progress.ts::PROMOTION_EXAM_PASS_PERCENT) یکسان بماند؛
/// رفع اشکال ناهماهنگی: قبلاً چند جای کلاینت (نتیجهٔ بلافاصله بعد از تحویل،
/// انیمیشن جشن، صفحهٔ مرور) خودشان با ۵۰٪ هاردکد محاسبه می‌کردند، در حالی‌که
/// فهرست نتایج/داشبورد والدین از سرور با ۸۰٪ می‌آمد — همان امتحان می‌توانست
/// در یک صفحه «قبول» و در صفحهٔ دیگر «ناکام» دیده شود. اکنون سرور خودش
/// `passed` را محاسبه و می‌فرستد؛ این ثابت فقط برای Mock DataSource (بدون
/// سرور واقعی) نگه داشته شده تا همان‌جا هم هماهنگ باشد.
const double kExamPassPercent = 80.0;

extension QuestionTypeX on QuestionType {
  String get key {
    switch (this) {
      case QuestionType.mcq:
        return 'mcq';
      case QuestionType.trueFalse:
        return 'true_false';
      case QuestionType.essay:
        return 'essay';
    }
  }

  static QuestionType fromKey(String? key) {
    switch (key) {
      case 'true_false':
        return QuestionType.trueFalse;
      case 'essay':
        return QuestionType.essay;
      case 'mcq':
      default:
        return QuestionType.mcq;
    }
  }
}

class ExamSummary extends Equatable {
  final String id;
  final String subjectNameFa;
  final ExamType type;
  final int durationMinutes;
  final int questionCount;
  final int gradeNumber;

  /// بهترین نمرهٔ قبلیِ همین شاگرد در این امتحان (اگر قبلاً تلاش کرده)، یا
  /// null اگر هنوز هرگز نکرده — رفع اشکال: قبلاً این اطلاع اصلاً وجود
  /// نداشت، پس UI همیشه فقط دکمهٔ «شروع» نشان می‌داد، حتی برای امتحانی که
  /// شاگرد قبلاً کامیاب شده بود.
  final double? bestScorePercent;
  final bool passed;

  const ExamSummary({
    required this.id,
    required this.subjectNameFa,
    required this.type,
    required this.durationMinutes,
    required this.questionCount,
    this.gradeNumber = 0,
    this.bestScorePercent,
    this.passed = false,
  });

  bool get isFinal => type == ExamType.finalExam;
  bool get attempted => bestScorePercent != null;

  @override
  List<Object?> get props => [id, bestScorePercent];
}

class ExamQuestion extends Equatable {
  final String id;
  final String text;
  final QuestionType qType;
  final List<String> options; // برای تشریحی خالی است
  final int correctIndex; // فقط سؤالات بسته — نمره‌دهی خودکار Backend، بخش ۷.۲

  const ExamQuestion({
    required this.id,
    required this.text,
    this.qType = QuestionType.mcq,
    required this.options,
    required this.correctIndex,
  });

  bool get isEssay => qType == QuestionType.essay;

  @override
  List<Object?> get props => [id];
}

class ExamResult extends Equatable {
  final double scorePercent;
  final int correctCount;
  final int totalCount;

  /// رفع اشکال ارتقای صنف: اگر این امتحان «نهایی» بود و شاگرد بلافاصله
  /// روی سرور واقعاً ارتقا یافت (بخش lib/progress.ts::promoteIfEligible)،
  /// این دو فیلد پر می‌شوند تا رابط کاربری بدون تأخیر خبر بدهد.
  final bool promoted;
  final int? newGrade;

  /// شناسهٔ تلاش ثبت‌شده — برای باز کردن مستقیم صفحهٔ «مرور پاسخ‌ها»
  /// بلافاصله بعد از تحویل امتحان (بدون نیاز به رفتن به فهرست نتایج).
  final String? attemptId;

  /// قبول/ناکام — از سرور می‌آید (همان آستانهٔ [kExamPassPercent])، نه یک
  /// محاسبهٔ محلی جداگانه، تا با فهرست نتایج/داشبورد والدین هماهنگ بماند.
  final bool passed;

  const ExamResult({
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    this.promoted = false,
    this.newGrade,
    this.attemptId,
    this.passed = false,
  });

  @override
  List<Object?> get props => [scorePercent];
}

/// یک ردیف در «نتایج امتحانات رسمی» — طبق درخواست کاربر: بعد از دادن هر
/// امتحان، به‌جای دیدن دوبارهٔ آن در فهرست «قابل‌شروع»، این‌جا با نمره،
/// مضمون، صنف و تاریخ نمایش داده می‌شود؛ با کلیک روی آن، مرور سؤال‌به‌سؤال
/// باز می‌شود (`ExamAttemptReview`). همان صفحه هم برای شاگرد و هم برای
/// والدِ لینک‌شده (با `studentId`) استفاده می‌شود تا داده در هر دو داشبورد
/// دقیقاً یکسان باشد.
class ExamResultSummary extends Equatable {
  final String attemptId;
  final String examId;
  final String examTitle;
  final String subjectNameFa;
  final int gradeNumber;
  final ExamType type;
  final double scorePercent;
  final int correctCount;
  final int totalCount;
  final bool passed;
  final DateTime submittedAt;

  const ExamResultSummary({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.subjectNameFa,
    required this.gradeNumber,
    required this.type,
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
    required this.submittedAt,
  });

  @override
  List<Object?> get props => [attemptId];
}

/// یک سؤال در صفحهٔ مرور — همراه با پاسخ شاگرد و اینکه درست بوده یا غلط.
/// برخلاف حین دادن امتحان، اینجا `correctIndex` واقعی هم فرستاده می‌شود
/// (امتحان قبلاً تمام شده — خطر تقلب دیگر معنا ندارد).
class ExamReviewQuestion extends Equatable {
  final String id;
  final String text;
  final QuestionType qType;
  final List<String> options;
  final int correctIndex;
  final int studentAnswerIndex; // -1 یعنی بی‌پاسخ یا سؤال تشریحی
  final String studentAnswerText; // فقط تشریحی
  final String modelAnswerText; // فقط تشریحی — پاسخ نمونه
  final bool? isCorrect; // null فقط وقتی تشریحی و AI نمره نداده (بدون کلید)
  final double? essayScore; // 0..1
  final String essayFeedback;

  const ExamReviewQuestion({
    required this.id,
    required this.text,
    required this.qType,
    required this.options,
    required this.correctIndex,
    required this.studentAnswerIndex,
    this.studentAnswerText = '',
    this.modelAnswerText = '',
    this.isCorrect,
    this.essayScore,
    this.essayFeedback = '',
  });

  bool get isEssay => qType == QuestionType.essay;
  bool get wasSkipped => !isEssay && studentAnswerIndex < 0;

  @override
  List<Object?> get props => [id];
}

/// جزئیات کامل یک تلاش امتحان — سرصفحه + همهٔ سؤالات برای مرور.
class ExamAttemptReview extends Equatable {
  final String attemptId;
  final String examId;
  final String examTitle;
  final String subjectNameFa;
  final int gradeNumber;
  final ExamType type;
  final double scorePercent;
  final int correctCount;
  final int totalCount;
  final DateTime submittedAt;
  final List<ExamReviewQuestion> questions;

  /// قبول/ناکام — از سرور می‌آید (همان آستانهٔ [kExamPassPercent])، هماهنگ
  /// با `ExamResult.passed`/`ExamResultSummary.passed`.
  final bool passed;

  const ExamAttemptReview({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.subjectNameFa,
    required this.gradeNumber,
    required this.type,
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.submittedAt,
    required this.questions,
    required this.passed,
  });

  @override
  List<Object?> get props => [attemptId];
}
