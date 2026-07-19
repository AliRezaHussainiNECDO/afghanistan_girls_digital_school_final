import 'package:equatable/equatable.dart';
import '../../../../exams/domain/entities/exam_entities.dart';

// نوع سؤال (QuestionType) بین بخش شاگرد و مدیر مشترک است — یک‌جا تعریف شده
// (exam_entities.dart) و اینجا re-export می‌شود تا مصرف‌کننده‌های بخش مدیر
// بدون import جداگانه به آن دسترسی داشته باشند و منطق دو نسخه‌ای نشود.
export '../../../../exams/domain/entities/exam_entities.dart' show ExamType, QuestionType, QuestionTypeX;

/// وضعیت انتشار امتحان — مطابق ستون `status` جدول واقعی `exams`
/// (backend/migrations/0004_exams.sql): draft|published|closed.
enum ExamAdminStatus { draft, published, closed }

extension ExamAdminStatusX on ExamAdminStatus {
  String get key {
    switch (this) {
      case ExamAdminStatus.draft:
        return 'draft';
      case ExamAdminStatus.published:
        return 'published';
      case ExamAdminStatus.closed:
        return 'closed';
    }
  }

  static ExamAdminStatus fromKey(String key) {
    switch (key) {
      case 'published':
        return ExamAdminStatus.published;
      case 'closed':
        return ExamAdminStatus.closed;
      case 'draft':
      default:
        return ExamAdminStatus.draft;
    }
  }
}

extension ExamTypeX on ExamType {
  /// کلید ماشینی مطابق ستون `type` جدول `exams` (بخش ۷.۱ سند).
  String get key {
    switch (this) {
      case ExamType.dailyQuiz:
        return 'daily_quiz';
      case ExamType.homework:
        return 'homework';
      case ExamType.monthly:
        return 'monthly';
      case ExamType.finalExam:
        return 'final';
    }
  }

  static ExamType fromKey(String key) {
    switch (key) {
      case 'homework':
        return ExamType.homework;
      case 'monthly':
        return ExamType.monthly;
      case 'final':
        return ExamType.finalExam;
      case 'daily_quiz':
      default:
        return ExamType.dailyQuiz;
    }
  }
}

/// یک ردیف امتحان از دید مدیر — شامل وضعیت واقعی/تعداد سؤالات (رفع اشکال:
/// قبلاً هیچ راهی برای مدیر جهت ساخت امتحان/سؤال از داخل برنامه وجود
/// نداشت؛ تنها دادهٔ موجود دو امتحانِ نمونهٔ Seed برای صنف ۷ بود و هیچ
/// امتحان نوع «نهایی» برای هیچ صنفی وجود نداشت — یعنی سیستم ارتقای صنف
/// عملاً از مسیر امتحان واقعی هرگز قابل تکمیل نبود).
class AdminExamRow extends Equatable {
  final String id;
  final String subjectId;
  final String subjectNameFa;
  final int gradeNumber;
  final ExamType type;
  final String title;
  final int durationMinutes;
  final ExamAdminStatus status;
  final int questionCount;
  final DateTime createdAt;

  const AdminExamRow({
    required this.id,
    required this.subjectId,
    this.subjectNameFa = '',
    required this.gradeNumber,
    required this.type,
    required this.title,
    this.durationMinutes = 10,
    this.status = ExamAdminStatus.draft,
    this.questionCount = 0,
    required this.createdAt,
  });

  AdminExamRow copyWith({
    String? subjectId,
    String? subjectNameFa,
    int? gradeNumber,
    ExamType? type,
    String? title,
    int? durationMinutes,
    ExamAdminStatus? status,
    int? questionCount,
  }) =>
      AdminExamRow(
        id: id,
        subjectId: subjectId ?? this.subjectId,
        subjectNameFa: subjectNameFa ?? this.subjectNameFa,
        gradeNumber: gradeNumber ?? this.gradeNumber,
        type: type ?? this.type,
        title: title ?? this.title,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        status: status ?? this.status,
        questionCount: questionCount ?? this.questionCount,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, subjectId, gradeNumber, type, title, durationMinutes, status, questionCount];
}

/// یک سؤال امتحان — پاسخ صحیح/پاسخ نمونه فقط در همین بخش مدیر دیده می‌شود
/// (endpoint شاگردی `correctIndex`/`answerText` را هرگز برنمی‌گرداند — بخش ۷.۲).
///
/// [qType] (migration 0030): چهارگزینه‌ای | صحیح‌وغلط | تشریحی.
/// [answerText]: پاسخ نمونهٔ سؤال تشریحی — کلید نمره‌دهی AI سمت سرور.
class AdminQuestionRow extends Equatable {
  final String id;
  final String examId;
  final String text;
  final QuestionType qType;
  final List<String> options; // برای تشریحی خالی است
  final int correctIndex; // برای تشریحی -۱
  final int orderIndex;
  final String answerText;

  const AdminQuestionRow({
    required this.id,
    required this.examId,
    required this.text,
    this.qType = QuestionType.mcq,
    required this.options,
    required this.correctIndex,
    this.orderIndex = 0,
    this.answerText = '',
  });

  AdminQuestionRow copyWith({
    String? text,
    QuestionType? qType,
    List<String>? options,
    int? correctIndex,
    int? orderIndex,
    String? answerText,
  }) =>
      AdminQuestionRow(
        id: id,
        examId: examId,
        text: text ?? this.text,
        qType: qType ?? this.qType,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        orderIndex: orderIndex ?? this.orderIndex,
        answerText: answerText ?? this.answerText,
      );

  @override
  List<Object?> get props => [id, examId, text, qType, options, correctIndex, orderIndex, answerText];
}

/// پارامترهای «تولید سؤال با هوش مصنوعی» — تعداد دلخواه از هر نوع؛ صنف و
/// مضمون از خودِ امتحان گرفته می‌شود (POST /admin/exams/:id/generate-questions).
class GenerateQuestionsParams extends Equatable {
  final String examId;
  final int mcqCount;
  final int trueFalseCount;
  final int essayCount;
  final String topic;

  const GenerateQuestionsParams({
    required this.examId,
    this.mcqCount = 0,
    this.trueFalseCount = 0,
    this.essayCount = 0,
    this.topic = '',
  });

  int get total => mcqCount + trueFalseCount + essayCount;

  @override
  List<Object?> get props => [examId, mcqCount, trueFalseCount, essayCount, topic];
}
