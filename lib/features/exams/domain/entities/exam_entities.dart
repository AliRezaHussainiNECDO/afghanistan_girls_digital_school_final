import 'package:equatable/equatable.dart';

/// طبق بخش ۷.۱ سند.
enum ExamType { dailyQuiz, homework, monthly, finalExam }

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
  final List<String> options;
  final int correctIndex; // فقط سؤالات بسته — نمره‌دهی خودکار Backend، بخش ۷.۲

  const ExamQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
  });

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

  const ExamResult({
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    this.promoted = false,
    this.newGrade,
  });

  @override
  List<Object?> get props => [scorePercent];
}
