import 'package:equatable/equatable.dart';

/// وضعیت یک مشق — دقیقاً هماهنگ با ستون `status` جدول `student_homeworks`
/// (بک‌اند: routes/homework.ts).
enum HomeworkStatus { pending, submitted, graded }

HomeworkStatus homeworkStatusFromApi(String? raw) => switch (raw) {
      'submitted' => HomeworkStatus.submitted,
      'graded' => HomeworkStatus.graded,
      _ => HomeworkStatus.pending,
    };

/// «مشق کاغذی + نمره‌دهی هوشمند» — شاگرد روی کاغذ حل می‌کند، عکس می‌فرستد،
/// و هوش مصنوعی (Vision) دست‌خط را می‌خواند و نمره/بازخورد می‌دهد.
///
/// `classLevel` عمداً همراه هر رکورد ذخیره می‌شود (نه گرفته‌شده از صنف فعلی
/// شاگرد در لحظهٔ نمایش) تا اگر شاگرد بعداً ارتقا یافت، تاریخچهٔ مشق‌های صنف
/// قبلی هم درست بماند؛ فهرست «مشق‌های من» در سرور به‌طور خودکار بر پایهٔ صنف
/// *فعلی* شاگرد فیلتر می‌شود (بخش `GET /homework` در routes/homework.ts).
class Homework extends Equatable {
  final String id;
  final String studentId;
  final String subjectId;
  final String subjectNameFa;
  final String chapterId;
  final String lessonId;
  final int classLevel;
  final String questionText;
  final String hintText;
  final HomeworkStatus status;
  final String studentImageUrl;
  final String extractedText;
  final int? aiScore;
  final String aiFeedback;
  final DateTime createdAt;
  final DateTime? submittedAt;
  final DateTime? gradedAt;

  const Homework({
    required this.id,
    required this.studentId,
    required this.subjectId,
    this.subjectNameFa = '',
    this.chapterId = '',
    this.lessonId = '',
    required this.classLevel,
    this.questionText = '',
    this.hintText = '',
    this.status = HomeworkStatus.pending,
    this.studentImageUrl = '',
    this.extractedText = '',
    this.aiScore,
    this.aiFeedback = '',
    required this.createdAt,
    this.submittedAt,
    this.gradedAt,
  });

  bool get hasImage => studentImageUrl.trim().isNotEmpty;
  bool get isGraded => status == HomeworkStatus.graded && aiScore != null;
  bool get canDiscussGrade => isGraded;

  @override
  List<Object?> get props => [id, status, aiScore, studentImageUrl];
}

/// خلاصهٔ فهرست مشق‌ها — همراه با صنف فعلی و میانگین نمرهٔ شاگرد (برای هدر
/// داشبورد)؛ سرور این دو مقدار را همراه فهرست برمی‌گرداند تا کلاینت مجبور
/// نباشد دوباره محاسبه کند (`GET /homework` در routes/homework.ts).
class HomeworkListResult extends Equatable {
  final int classLevel;
  final double? averageScore;
  final List<Homework> homeworks;

  const HomeworkListResult({
    required this.classLevel,
    this.averageScore,
    this.homeworks = const [],
  });

  @override
  List<Object?> get props => [classLevel, averageScore, homeworks];
}

/// یک پیام در گفت‌وگوی «شاگرد ↔ معلم هوشمند» دربارهٔ یک مشق مشخص.
enum HomeworkReplySender { student, ai }

class HomeworkReply extends Equatable {
  final String id;
  final String homeworkId;
  final HomeworkReplySender sender;
  final String text;
  final DateTime createdAt;

  const HomeworkReply({
    required this.id,
    required this.homeworkId,
    required this.sender,
    required this.text,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id];
}
