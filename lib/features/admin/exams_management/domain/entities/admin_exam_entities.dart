import 'package:equatable/equatable.dart';
import '../../../../exams/domain/entities/exam_entities.dart';

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

/// یک سؤال چهارگزینه‌ای — پاسخ صحیح فقط در همین بخش مدیر دیده می‌شود
/// (endpoint شاگردی `correctIndex` را هرگز برنمی‌گرداند — بخش ۷.۲).
class AdminQuestionRow extends Equatable {
  final String id;
  final String examId;
  final String text;
  final List<String> options;
  final int correctIndex;
  final int orderIndex;

  const AdminQuestionRow({
    required this.id,
    required this.examId,
    required this.text,
    required this.options,
    required this.correctIndex,
    this.orderIndex = 0,
  });

  AdminQuestionRow copyWith({
    String? text,
    List<String>? options,
    int? correctIndex,
    int? orderIndex,
  }) =>
      AdminQuestionRow(
        id: id,
        examId: examId,
        text: text ?? this.text,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        orderIndex: orderIndex ?? this.orderIndex,
      );

  @override
  List<Object?> get props => [id, examId, text, options, correctIndex, orderIndex];
}
