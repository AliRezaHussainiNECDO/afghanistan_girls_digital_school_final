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

  const CurriculumBook({
    required this.id,
    required this.subjectId,
    required this.title,
    required this.uploadedAt,
    required this.pageCount,
    required this.gradeId,
    required this.extractedText,
  });

  int get charCount => extractedText.length;

  CurriculumBook copyWith({String? title}) => CurriculumBook(
        id: id,
        subjectId: subjectId,
        title: title ?? this.title,
        uploadedAt: uploadedAt,
        pageCount: pageCount,
        gradeId: gradeId,
        extractedText: extractedText,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectId': subjectId,
        'title': title,
        'uploadedAt': uploadedAt.toIso8601String(),
        'pageCount': pageCount,
        'gradeId': gradeId,
        'extractedText': extractedText,
      };

  factory CurriculumBook.fromJson(Map<String, dynamic> json) => CurriculumBook(
        id: json['id'] as String,
        subjectId: json['subjectId'] as String,
        title: json['title'] as String,
        uploadedAt: DateTime.tryParse(json['uploadedAt'] as String? ?? '') ?? DateTime.now(),
        pageCount: json['pageCount'] as int? ?? 0,
        gradeId: json['gradeId'] as int? ?? 0,
        extractedText: json['extractedText'] as String? ?? '',
      );

  @override
  List<Object?> get props => [id, subjectId, title, uploadedAt, pageCount, gradeId];
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
