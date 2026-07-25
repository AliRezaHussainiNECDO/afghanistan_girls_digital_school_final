import 'package:equatable/equatable.dart';
import '../../../exams/domain/entities/exam_entities.dart' show QuestionType;

/// «آزمون فصل» — طبق درخواست صاحب پروژه: وقتی شاگرد تمام درس‌های یک فصل را
/// می‌بیند، سیستم خودکار (backend/src/lib/chapterQuiz.ts) با هوش مصنوعی
/// حداقل ۱۲ سؤال ترکیبی می‌سازد. آزمون سخت‌گیرانه نیست — هدف حس
/// مسئولیت‌پذیری است؛ صرفِ ارسال آن (یک‌بار) فصل بعدی را باز می‌کند.
class ChapterQuizQuestion extends Equatable {
  final String id;
  final String text;
  final QuestionType qType;
  final List<String> options;

  const ChapterQuizQuestion({
    required this.id,
    required this.text,
    required this.qType,
    required this.options,
  });

  bool get isEssay => qType == QuestionType.essay;

  @override
  List<Object?> get props => [id];
}

/// فورم کامل آزمون فصل — قبل از ارسال ([submitted]=false، بدون پاسخ) یا بعد
/// از ارسال ([submitted]=true، همراه با نمره و مرور سؤال‌به‌سؤال).
class ChapterQuizForm extends Equatable {
  final String chapterId;
  final String quizId;
  final String title;
  final double passThreshold;
  final bool submitted;
  final List<ChapterQuizQuestion> questions;

  // فقط وقتی submitted=true پر می‌شوند:
  final double? scorePercent;
  final int? correctCount;
  final int? totalCount;
  final bool? passed;
  final DateTime? submittedAt;
  final List<ChapterQuizReviewQuestion>? reviewQuestions;

  const ChapterQuizForm({
    required this.chapterId,
    required this.quizId,
    required this.title,
    required this.passThreshold,
    required this.submitted,
    required this.questions,
    this.scorePercent,
    this.correctCount,
    this.totalCount,
    this.passed,
    this.submittedAt,
    this.reviewQuestions,
  });

  /// هنوز آزمونی برای این فصل آماده نشده (شاگرد هنوز همهٔ درس‌ها را ندیده،
  /// یا AI موقتاً در دسترس نبوده) — کد خطای سرور `QUIZ_NOT_READY`.
  static const notReady = ChapterQuizForm(
    chapterId: '',
    quizId: '',
    title: '',
    passThreshold: 40,
    submitted: false,
    questions: [],
  );
  bool get isNotReady => quizId.isEmpty;

  @override
  List<Object?> get props => [chapterId, quizId, submitted];
}

/// یک سؤال در فورم مرور — پاسخ شاگرد + درست/غلط (بعد از ارسال).
class ChapterQuizReviewQuestion extends Equatable {
  final String id;
  final String text;
  final QuestionType qType;
  final List<String> options;
  final int correctIndex;
  final int studentAnswerIndex;
  final String studentAnswerText;
  final String modelAnswerText;
  final bool? isCorrect;
  final double? essayScore;
  final String essayFeedback;

  const ChapterQuizReviewQuestion({
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

  @override
  List<Object?> get props => [id];
}

class ChapterQuizResult extends Equatable {
  final double scorePercent;
  final int correctCount;
  final int totalCount;
  final bool passed;

  const ChapterQuizResult({
    required this.scorePercent,
    required this.correctCount,
    required this.totalCount,
    required this.passed,
  });

  @override
  List<Object?> get props => [scorePercent];
}
