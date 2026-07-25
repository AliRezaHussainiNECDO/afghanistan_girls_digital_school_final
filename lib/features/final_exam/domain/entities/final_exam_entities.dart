import 'package:equatable/equatable.dart';
import '../../../exams/domain/entities/exam_entities.dart' show QuestionType;

export '../../../exams/domain/entities/exam_entities.dart' show QuestionType, QuestionTypeX;

/// امتحان فاینل چندمضمونهٔ صنف (backend/src/routes/finalExams.ts) — برخلاف
/// امتحان «نهاییِ» قدیمی (تک‌مضمونه)، این یک امتحان واحد برای کل صنف است:
/// حداقل ۳ سؤال از هر مضمون، در مجموع حدود ۳۰ سؤال. اگر شاگرد قبول نشود،
/// دقیقاً ۱۵ روز بعد دوباره مجاز به تلاش است.
class FinalExamInfo extends Equatable {
  final String id;
  final String title;
  final int gradeNumber;
  final int questionCount;
  final double passThreshold;

  const FinalExamInfo({
    required this.id,
    required this.title,
    required this.gradeNumber,
    required this.questionCount,
    required this.passThreshold,
  });

  @override
  List<Object?> get props => [id];
}

/// وضعیت واجد‌شرایطیِ شاگرد برای امتحان فاینل صنف خودش — سرور این را زنده
/// (بدون هیچ Cron) بر اساس آخرین تلاش محاسبه می‌کند.
class FinalExamAvailability extends Equatable {
  final FinalExamInfo? exam; // null یعنی هنوز هیچ امتحان فاینلی برای این صنف منتشر نشده
  final bool eligible;
  final int nextAttemptNumber;
  final String? reason; // 'passed' | 'cooldown' | null
  final DateTime? retakeAvailableAt;
  final double? bestScorePercent;

  const FinalExamAvailability({
    this.exam,
    required this.eligible,
    required this.nextAttemptNumber,
    this.reason,
    this.retakeAvailableAt,
    this.bestScorePercent,
  });

  bool get alreadyPassed => reason == 'passed';
  bool get inCooldown => reason == 'cooldown';

  @override
  List<Object?> get props => [exam, eligible, reason];
}

class FinalExamQuestion extends Equatable {
  final String id;
  final String text;
  final QuestionType qType;
  final List<String> options;
  final String subjectId;
  final String subjectNameFa;

  const FinalExamQuestion({
    required this.id,
    required this.text,
    required this.qType,
    required this.options,
    required this.subjectId,
    required this.subjectNameFa,
  });

  bool get isEssay => qType == QuestionType.essay;

  @override
  List<Object?> get props => [id];
}

class FinalExamResult extends Equatable {
  final String attemptId;
  final double scorePercent;
  final int correctCount;
  final int totalCount;
  final bool passed;
  final bool promoted;
  final int? newGrade;

  const FinalExamResult({
    required this.attemptId,
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
    this.promoted = false,
    this.newGrade,
  });

  @override
  List<Object?> get props => [attemptId];
}

class FinalExamResultSummary extends Equatable {
  final String attemptId;
  final String examId;
  final String examTitle;
  final int gradeNumber;
  final int attemptNumber;
  final double scorePercent;
  final int correctCount;
  final int totalCount;
  final bool passed;
  final DateTime submittedAt;
  final DateTime? retakeAvailableAt;

  const FinalExamResultSummary({
    required this.attemptId,
    required this.examId,
    required this.examTitle,
    required this.gradeNumber,
    required this.attemptNumber,
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
    required this.submittedAt,
    this.retakeAvailableAt,
  });

  @override
  List<Object?> get props => [attemptId];
}

class FinalExamReviewQuestion extends Equatable {
  final String id;
  final String text;
  final QuestionType qType;
  final String subjectNameFa;
  final List<String> options;
  final int correctIndex;
  final int studentAnswerIndex;
  final String studentAnswerText;
  final String modelAnswerText;
  final bool? isCorrect;
  final double? essayScore;
  final String essayFeedback;

  const FinalExamReviewQuestion({
    required this.id,
    required this.text,
    required this.qType,
    required this.subjectNameFa,
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

  @override
  List<Object?> get props => [id];
}

class FinalExamAttemptReview extends Equatable {
  final String attemptId;
  final String examTitle;
  final int gradeNumber;
  final int attemptNumber;
  final double scorePercent;
  final int correctCount;
  final int totalCount;
  final bool passed;
  final DateTime submittedAt;
  final List<FinalExamReviewQuestion> questions;

  const FinalExamAttemptReview({
    required this.attemptId,
    required this.examTitle,
    required this.gradeNumber,
    required this.attemptNumber,
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
    required this.submittedAt,
    required this.questions,
  });

  @override
  List<Object?> get props => [attemptId];
}

// ══════════════════════════ مدیریت (فقط مدیر) ══════════════════════════════

enum FinalExamAdminStatus { draft, published, closed }

extension FinalExamAdminStatusX on FinalExamAdminStatus {
  String get key => switch (this) {
        FinalExamAdminStatus.draft => 'draft',
        FinalExamAdminStatus.published => 'published',
        FinalExamAdminStatus.closed => 'closed',
      };
  static FinalExamAdminStatus fromKey(String key) => switch (key) {
        'published' => FinalExamAdminStatus.published,
        'closed' => FinalExamAdminStatus.closed,
        _ => FinalExamAdminStatus.draft,
      };
}

class AdminFinalExamRow extends Equatable {
  final String id;
  final int gradeNumber;
  final String academicYear;
  final String title;
  final FinalExamAdminStatus status;
  final double passThreshold;
  final int questionCount;
  final DateTime createdAt;

  const AdminFinalExamRow({
    required this.id,
    required this.gradeNumber,
    required this.academicYear,
    required this.title,
    required this.status,
    required this.passThreshold,
    required this.questionCount,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, status, questionCount];
}

class AdminFinalExamQuestionRow extends Equatable {
  final String id;
  final String finalExamId;
  final String subjectId;
  final String subjectNameFa;
  final QuestionType qType;
  final String text;
  final List<String> options;
  final int correctIndex;
  final String answerText;
  final int orderIndex;

  const AdminFinalExamQuestionRow({
    required this.id,
    required this.finalExamId,
    required this.subjectId,
    this.subjectNameFa = '',
    required this.qType,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.answerText = '',
    this.orderIndex = 0,
  });

  @override
  List<Object?> get props => [id];
}

class GenerateFinalExamResult extends Equatable {
  final int savedCount;
  final List<String> failedSubjects;
  const GenerateFinalExamResult({required this.savedCount, required this.failedSubjects});
  @override
  List<Object?> get props => [savedCount, failedSubjects];
}
