import 'package:equatable/equatable.dart';

/// وضعیت انتشار محتوا (کتاب/سؤال). فقط دو حالت لازم است: پیش‌نویس یا منتشرشده.
enum PublishStatus { draft, published }

extension PublishStatusX on PublishStatus {
  String get key => this == PublishStatus.published ? 'published' : 'draft';
  static PublishStatus fromKey(String k) =>
      k == 'published' ? PublishStatus.published : PublishStatus.draft;
}

/// نوع سؤال — چهارجوابه / صحیح‌وغلط / تشریحی.
enum QuestionKind { mcq, trueFalse, essay }

extension QuestionKindX on QuestionKind {
  String get key {
    switch (this) {
      case QuestionKind.mcq:
        return 'mcq';
      case QuestionKind.trueFalse:
        return 'trueFalse';
      case QuestionKind.essay:
        return 'essay';
    }
  }

  static QuestionKind fromKey(String k) =>
      QuestionKind.values.firstWhere((e) => e.key == k, orElse: () => QuestionKind.mcq);
}

/// یک کتاب کتابخانه — منبع حقیقتِ مشترک بین «مدیریت محتوا» و «کتابخانهٔ شاگرد».
/// مدیر آن را (به‌همراه فایل پی‌دی‌اف و جزئیات) می‌سازد و منتشر می‌کند؛ همان
/// رکورد بدون تغییر برای شاگردان در کتابخانه قابل مشاهده/دانلود می‌شود.
class LibraryBook extends Equatable {
  final String id;
  final String title;
  final String subject; // مضمون
  final int gradeId; // ۷ الی ۱۲ (۰ = عمومی/بدون صنف)
  final String category; // کتاب درسی رسمی/کمک‌درسی/داستان/مهارت زندگی
  final String author;
  final String description;
  final String language;
  final String pdfFileName; // نام فایل نمایشی
  final String pdfPath; // مسیر محلی فایل پی‌دی‌اف (از file_picker — فقط لحظهٔ آپلود)
  final String pdfKey; // کلید فایل واقعی روی R2 سرور — منبع حقیقتِ «آیا فایل واقعی دارد؟»
  final double fileSizeMb;
  final int pageCount;
  final int coverIndex; // انتخاب رنگ جلد (۰..n)
  final bool includeInRag; // آیا متن این کتاب به معلم هوشمند داده شود؟
  final PublishStatus status;
  final DateTime uploadedAt;
  final DateTime updatedAt;

  const LibraryBook({
    required this.id,
    required this.title,
    required this.subject,
    this.gradeId = 0,
    this.category = 'کتاب درسی رسمی',
    this.author = '',
    this.description = '',
    this.language = 'دری',
    this.pdfFileName = '',
    this.pdfPath = '',
    this.pdfKey = '',
    this.fileSizeMb = 0,
    this.pageCount = 0,
    this.coverIndex = 0,
    this.includeInRag = false,
    this.status = PublishStatus.draft,
    required this.uploadedAt,
    required this.updatedAt,
  });

  // رفع اشکال: قبلاً «آیا فایل دارد؟» فقط از روی pdfPath (مسیر محلیِ لحظهٔ
  // انتخاب فایل، که بعد از آپلود/رفرش/دستگاه دیگر بی‌معنی است) تشخیص داده
  // می‌شد. منبع حقیقتِ واقعی، وجود pdfKey (فایل واقعاً روی سرور/R2) است.
  bool get hasPdf => pdfKey.isNotEmpty || pdfPath.isNotEmpty;
  String get gradeLabel => gradeId == 0 ? 'عمومی' : 'صنف $gradeId';

  LibraryBook copyWith({
    String? title,
    String? subject,
    int? gradeId,
    String? category,
    String? author,
    String? description,
    String? language,
    String? pdfFileName,
    String? pdfPath,
    String? pdfKey,
    double? fileSizeMb,
    int? pageCount,
    int? coverIndex,
    bool? includeInRag,
    PublishStatus? status,
    DateTime? updatedAt,
  }) =>
      LibraryBook(
        id: id,
        title: title ?? this.title,
        subject: subject ?? this.subject,
        gradeId: gradeId ?? this.gradeId,
        category: category ?? this.category,
        author: author ?? this.author,
        description: description ?? this.description,
        language: language ?? this.language,
        pdfFileName: pdfFileName ?? this.pdfFileName,
        pdfPath: pdfPath ?? this.pdfPath,
        pdfKey: pdfKey ?? this.pdfKey,
        fileSizeMb: fileSizeMb ?? this.fileSizeMb,
        pageCount: pageCount ?? this.pageCount,
        coverIndex: coverIndex ?? this.coverIndex,
        includeInRag: includeInRag ?? this.includeInRag,
        status: status ?? this.status,
        uploadedAt: uploadedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [id, title, subject, gradeId, status, pdfKey, pdfPath, updatedAt];
}

/// یک سؤال در بانک سؤالات — با پشتیبانی از سه نوع سؤال.
class BankQuestion extends Equatable {
  final String id;
  final String subject;
  final int gradeId;
  final String chapter; // فصل کتاب که سؤال از آن است
  final QuestionKind kind;
  final String text;
  final List<String> options; // فقط چهارجوابه
  final int correctIndex; // فقط چهارجوابه
  final bool correctBool; // فقط صحیح‌وغلط
  final String modelAnswer; // پاسخ نمونه/کلیدواژه‌ها — مبنای نمره‌دهی تشریحی
  final int points;
  final PublishStatus status;
  final bool aiGenerated;
  final DateTime createdAt;

  const BankQuestion({
    required this.id,
    required this.subject,
    this.gradeId = 0,
    this.chapter = '',
    required this.kind,
    required this.text,
    this.options = const [],
    this.correctIndex = 0,
    this.correctBool = true,
    this.modelAnswer = '',
    this.points = 1,
    this.status = PublishStatus.draft,
    this.aiGenerated = false,
    required this.createdAt,
  });

  BankQuestion copyWith({
    String? subject,
    int? gradeId,
    String? chapter,
    QuestionKind? kind,
    String? text,
    List<String>? options,
    int? correctIndex,
    bool? correctBool,
    String? modelAnswer,
    int? points,
    PublishStatus? status,
    bool? aiGenerated,
  }) =>
      BankQuestion(
        id: id,
        subject: subject ?? this.subject,
        gradeId: gradeId ?? this.gradeId,
        chapter: chapter ?? this.chapter,
        kind: kind ?? this.kind,
        text: text ?? this.text,
        options: options ?? this.options,
        correctIndex: correctIndex ?? this.correctIndex,
        correctBool: correctBool ?? this.correctBool,
        modelAnswer: modelAnswer ?? this.modelAnswer,
        points: points ?? this.points,
        status: status ?? this.status,
        aiGenerated: aiGenerated ?? this.aiGenerated,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props =>
      [id, subject, gradeId, chapter, kind, text, options, correctIndex, correctBool, status];
}

/// «امتحان» به‌صورت پویا از روی سؤالات منتشرشدهٔ یک مضمون+صنف ساخته می‌شود
/// (بدون نیاز به موجودیت جدا). این کلاس فقط یک نمای خلاصه برای لیست است.
class SubjectExam extends Equatable {
  final String subject;
  final int gradeId;
  final int questionCount;
  final int totalPoints;

  const SubjectExam({
    required this.subject,
    required this.gradeId,
    required this.questionCount,
    required this.totalPoints,
  });

  String get key => '$subject#$gradeId';
  String get gradeLabel => gradeId == 0 ? 'عمومی' : 'صنف $gradeId';

  @override
  List<Object?> get props => [subject, gradeId];
}

/// پروفایل سادهٔ شاگرد — یک شاگرد می‌تواند در چند صنف (۷ الی ۱۲) درس بخواند.
class StudentProfile extends Equatable {
  final String id;
  final String displayName;
  final List<int> gradeIds;

  const StudentProfile({required this.id, required this.displayName, required this.gradeIds});

  @override
  List<Object?> get props => [id];
}

/// پاسخ یک شاگرد به یک سؤال، به‌همراه نتیجهٔ نمره‌دهی.
class SubmissionAnswer extends Equatable {
  final String questionId;
  final String questionText;
  final QuestionKind kind;
  final List<String> options;
  final int? chosenIndex; // چهارجوابه
  final bool? chosenBool; // صحیح‌وغلط
  final String? essayText; // تشریحی
  final int? correctIndex;
  final bool? correctBool;
  final String modelAnswer;
  final double awardedPoints;
  final double maxPoints;
  final bool? isCorrect; // برای سؤالات بسته
  final String aiFeedback; // بازخورد هوش مصنوعی برای تشریحی

  const SubmissionAnswer({
    required this.questionId,
    required this.questionText,
    required this.kind,
    this.options = const [],
    this.chosenIndex,
    this.chosenBool,
    this.essayText,
    this.correctIndex,
    this.correctBool,
    this.modelAnswer = '',
    required this.awardedPoints,
    required this.maxPoints,
    this.isCorrect,
    this.aiFeedback = '',
  });

  @override
  List<Object?> get props => [questionId, awardedPoints];
}

/// یک نوبت پاسخ‌دهی کامل شاگرد به یک امتحان (مضمون+صنف).
class Submission extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final int gradeId;
  final String subject;
  final DateTime submittedAt;
  final List<SubmissionAnswer> answers;
  final double scorePercent;
  final double earnedPoints;
  final double totalPoints;
  final bool aiAssisted;

  const Submission({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.gradeId,
    required this.subject,
    required this.submittedAt,
    required this.answers,
    required this.scorePercent,
    required this.earnedPoints,
    required this.totalPoints,
    this.aiAssisted = false,
  });

  String get gradeLabel => gradeId == 0 ? 'عمومی' : 'صنف $gradeId';
  bool get passed => scorePercent >= 50;

  @override
  List<Object?> get props => [id];
}
