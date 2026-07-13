import 'package:equatable/equatable.dart';

/// چرخهٔ وضعیت محتوا طبق بخش ۱۴ سند: پیش‌نویس → تأییدشده → منتشرشده.
/// (بایگانی برای محتوایی که از انتشار خارج می‌شود.)
enum ContentStatus { draft, approved, published, archived }

extension ContentStatusX on ContentStatus {
  /// کلید ماشینی برای ذخیره/فیلتر.
  String get key {
    switch (this) {
      case ContentStatus.draft:
        return 'draft';
      case ContentStatus.approved:
        return 'approved';
      case ContentStatus.published:
        return 'published';
      case ContentStatus.archived:
        return 'archived';
    }
  }

  /// آیا این وضعیت اجازهٔ حرکت به وضعیت بعدی در گردش‌کار را دارد؟
  ContentStatus? get next {
    switch (this) {
      case ContentStatus.draft:
        return ContentStatus.approved;
      case ContentStatus.approved:
        return ContentStatus.published;
      case ContentStatus.published:
        return null; // منتشرشده انتهای گردش‌کار پیش‌رونده است.
      case ContentStatus.archived:
        return ContentStatus.draft; // بازگردانی از بایگانی.
    }
  }

  static ContentStatus fromKey(String key) {
    return ContentStatus.values.firstWhere(
      (s) => s.key == key,
      orElse: () => ContentStatus.draft,
    );
  }
}

/// نوع محتوا — برای منطق مشترک UI/آمار.
enum CmsContentType { book, lesson, question }

class CmsBookRow extends Equatable {
  final String id;
  final String title;
  final String category;
  final String author;
  final String grade; // مثلاً «صنف نهم»
  final int chaptersCount;
  final String description;
  final ContentStatus status;
  final DateTime updatedAt;

  const CmsBookRow({
    required this.id,
    required this.title,
    required this.category,
    this.author = '',
    this.grade = '',
    this.chaptersCount = 0,
    this.description = '',
    this.status = ContentStatus.draft,
    required this.updatedAt,
  });

  CmsBookRow copyWith({
    String? title,
    String? category,
    String? author,
    String? grade,
    int? chaptersCount,
    String? description,
    ContentStatus? status,
    DateTime? updatedAt,
  }) =>
      CmsBookRow(
        id: id,
        title: title ?? this.title,
        category: category ?? this.category,
        author: author ?? this.author,
        grade: grade ?? this.grade,
        chaptersCount: chaptersCount ?? this.chaptersCount,
        description: description ?? this.description,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props => [id, title, category, author, grade, chaptersCount, description, status, updatedAt];
}

class CmsLessonRow extends Equatable {
  final String id;
  final String title;
  final String chapterTitle;
  final String bookTitle;
  final int durationMinutes;
  final String content; // خلاصهٔ متن درس
  final ContentStatus status;
  final DateTime updatedAt;

  const CmsLessonRow({
    required this.id,
    required this.title,
    required this.chapterTitle,
    this.bookTitle = '',
    this.durationMinutes = 0,
    this.content = '',
    this.status = ContentStatus.draft,
    required this.updatedAt,
  });

  CmsLessonRow copyWith({
    String? title,
    String? chapterTitle,
    String? bookTitle,
    int? durationMinutes,
    String? content,
    ContentStatus? status,
    DateTime? updatedAt,
  }) =>
      CmsLessonRow(
        id: id,
        title: title ?? this.title,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        bookTitle: bookTitle ?? this.bookTitle,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        content: content ?? this.content,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, title, chapterTitle, bookTitle, durationMinutes, content, status, updatedAt];
}

class CmsQuestionRow extends Equatable {
  final String id;
  final String text;
  final String difficulty; // easy | medium | hard
  final String subject; // مضمون
  final String type; // mcq | essay
  final List<String> options;
  final String answer;
  final ContentStatus status;
  final DateTime updatedAt;

  const CmsQuestionRow({
    required this.id,
    required this.text,
    required this.difficulty,
    this.subject = '',
    this.type = 'mcq',
    this.options = const [],
    this.answer = '',
    this.status = ContentStatus.draft,
    required this.updatedAt,
  });

  CmsQuestionRow copyWith({
    String? text,
    String? difficulty,
    String? subject,
    String? type,
    List<String>? options,
    String? answer,
    ContentStatus? status,
    DateTime? updatedAt,
  }) =>
      CmsQuestionRow(
        id: id,
        text: text ?? this.text,
        difficulty: difficulty ?? this.difficulty,
        subject: subject ?? this.subject,
        type: type ?? this.type,
        options: options ?? this.options,
        answer: answer ?? this.answer,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, text, difficulty, subject, type, options, answer, status, updatedAt];
}

/// طبق بخش ۳ب.۳ سند: مدیریت Invite Code توسط Admin (صدور دسته‌ای/ردیابی/ابطال).
class CmsInviteCodeRow extends Equatable {
  final String id;
  final String code;
  final String batchLabel;
  final String status; // unused | used | revoked | expired
  final DateTime createdAt;

  /// قابلیت بازبینی (بخش ۱.۲): چه کسی این کد را هنگام ثبت‌نام مصرف کرد.
  final String usedByName;

  /// تاریخ انقضای کد — کد منقضی در راجستر پذیرفته نمی‌شود.
  final DateTime? expiresAt;

  const CmsInviteCodeRow({
    required this.id,
    required this.code,
    required this.batchLabel,
    required this.status,
    required this.createdAt,
    this.usedByName = '',
    this.expiresAt,
  });

  int get remainingDays {
    final e = expiresAt;
    if (e == null) return 0;
    final d = e.difference(DateTime.now());
    return d.isNegative ? 0 : d.inDays;
  }

  @override
  List<Object?> get props => [id, status, usedByName];
}
