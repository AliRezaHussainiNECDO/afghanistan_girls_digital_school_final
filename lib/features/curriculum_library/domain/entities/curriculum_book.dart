import 'package:equatable/equatable.dart';

/// یک کتاب درسی رسمی (پی‌دی‌اف) که مدیریت برای یک مضمون آپلود کرده و متن
/// آن استخراج شده — منبع اصلی تدریس «معلم هوشمند» طبق درخواست کاربر.
class CurriculumBook extends Equatable {
  final String id;
  final String subjectId;
  final String title;
  final DateTime uploadedAt;
  final int pageCount;

  /// صنف مربوطهٔ این کتاب (۷ الی ۱۲) — طبق ساختار نصاب رسمی وزارت معارف که
  /// هر مضمون کتاب جداگانه به ازای هر صنف دارد. کتاب‌های قدیمی‌تر (پیش از
  /// افزودن این فیلد) با `0` علامت‌گذاری می‌شوند (یعنی «بدون صنف مشخص»).
  final int gradeId;

  /// متن کامل استخراج‌شده از پی‌دی‌اف — پایهٔ RAG محلی معلم هوشمند.
  final String extractedText;

  /// چند فصل از این کتاب در نصاب داشبورد شاگردان منتشر شده (`chapters` روی
  /// سرور، پیوندشده با `source_book_id`). اگر کتاب آپلود شده ولی این عدد
  /// صفر است، یعنی نصاب شاگردان برای این کتاب هنوز خالی است — دقیقاً همان
  /// حالتی که «مدیریت معلم هوشمند» باید به مدیر نشان بدهد (طبق درخواست
  /// کاربر: هماهنگی کامل بین آپلود مدیر و نصاب شاگرد).
  final int chapterCount;

  const CurriculumBook({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.uploadedAt,
    required this.pageCount,
    required this.gradeId,
    required this.extractedText,
    this.chapterCount = 0,
  });

  int get charCount => extractedText.length;

  /// آیا این کتاب هنوز به فصل/درسِ قابل‌نمایش در نصاب شاگردان تبدیل نشده —
  /// نشانهٔ دقیق همان اشکالِ «کتاب آپلود شد ولی درسی نمایش داده نمی‌شود».
  bool get needsStructuring => chapterCount == 0;

  CurriculumBook copyWith({String? title, int? chapterCount}) => CurriculumBook(
        id: id,
        subjectId: subjectId,
        title: title ?? this.title,
        uploadedAt: uploadedAt,
        pageCount: pageCount,
        gradeId: gradeId,
        extractedText: extractedText,
        chapterCount: chapterCount ?? this.chapterCount,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'title': title,
        'uploadedAt': uploadedAt.toIso8601String(),
        'pageCount': pageCount,
        'gradeId': gradeId,
        'extractedText': extractedText,
        'chapterCount': chapterCount,
      };

  factory CurriculumBook.fromJson(Map<String, dynamic> json) => CurriculumBook(
        id: json['id'] as String,
        subjectId: json['subjectId'] as String,
        title: json['title'] as String,
        uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? '') ?? DateTime.now(),
        pageCount: json['pageCount'] as int? ?? 0,
        gradeId: json['gradeId'] as int? ?? 0,
        extractedText: json['extractedText'] as String? ?? '',
        chapterCount: json['chapterCount'] as int? ?? 0,
      );

  @override
  List<Object?> get props => [id, subjectId, title, uploadedAt, pageCount, gradeId, chapterCount];
}

/// یک بخش/قطعهٔ منسجم از متن کتاب — واحد پایهٔ «درس دادن» و جست‌وجوی معلم
/// هوشمند (طبق منطق Chunking سبک محلی، بدون نیاز به بک‌اند).
class BookSection extends Equatable {
  final String bookId;
  final String bookTitle;
  final int index;
  final String heading;
  final String content;

  const BookSection({
    required this.bookId,
    required this.bookTitle,
    required this.index,
    required this.heading,
    required this.content,
  });

  @override
  List<Object?> get props => [bookId, index];
}
