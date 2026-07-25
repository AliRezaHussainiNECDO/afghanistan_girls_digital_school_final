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

/// درسِ واقعیِ نصاب — بخش ۶ سند (جدول‌های `lessons`/`chapters`).
///
/// رفع اشکال: قبلاً این ردیف فقط برای جدول جداگانه و بی‌اثر `cms_lessons`
/// بود (بدون هیچ رابطه‌ای با صنف/مضمون/فصل واقعی) و هیچ شاگردی هرگز آن را
/// نمی‌دید. اکنون `gradeNumber`/`subjectId` اضافه شده تا مستقیماً به فصل
/// واقعیِ نصاب (پیدا/ساخته‌شده روی سرور) وصل شود؛ `bookTitle` حذف شد چون در
/// نصاب واقعی معنایی ندارد (کتاب مبدأ اختیاری است و از «کتابخانهٔ نصاب»
/// می‌آید، نه از این فرم).
class CmsLessonRow extends Equatable {
  final String id;
  final String title;
  final int gradeNumber; // ۷..۱۲
  final String subjectId; // مثلاً math, physics, ...
  final String chapterTitle;
  final int durationMinutes;
  final String content; // متن درس
  final ContentStatus status;
  final DateTime updatedAt;

  const CmsLessonRow({
    required this.id,
    required this.title,
    this.gradeNumber = 7,
    this.subjectId = '',
    required this.chapterTitle,
    this.durationMinutes = 0,
    this.content = '',
    this.status = ContentStatus.draft,
    required this.updatedAt,
  });

  CmsLessonRow copyWith({
    String? title,
    int? gradeNumber,
    String? subjectId,
    String? chapterTitle,
    int? durationMinutes,
    String? content,
    ContentStatus? status,
    DateTime? updatedAt,
  }) =>
      CmsLessonRow(
        id: id,
        title: title ?? this.title,
        gradeNumber: gradeNumber ?? this.gradeNumber,
        subjectId: subjectId ?? this.subjectId,
        chapterTitle: chapterTitle ?? this.chapterTitle,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        content: content ?? this.content,
        status: status ?? this.status,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  List<Object?> get props =>
      [id, title, gradeNumber, subjectId, chapterTitle, durationMinutes, content, status, updatedAt];
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

  CmsInviteCodeRow copyWith({
    String? status,
    String? usedByName,
  }) =>
      CmsInviteCodeRow(
        id: id,
        code: code,
        batchLabel: batchLabel,
        status: status ?? this.status,
        createdAt: createdAt,
        usedByName: usedByName ?? this.usedByName,
        expiresAt: expiresAt,
      );

  @override
  List<Object?> get props => [id, status, usedByName];
}
