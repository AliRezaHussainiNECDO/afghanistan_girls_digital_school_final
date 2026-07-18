import '../../../../../core/instructor/instructor_invite_store.dart';
import '../../../../../core/student/student_invite_store.dart';
import '../../domain/entities/cms_entities.dart';
import 'cms_remote_datasource.dart' show CmsDataSource;

/// منبع دادهٔ آزمایشی CMS (فاز ۱: پروتوتایپ با دادهٔ درون‌حافظه‌ای).
/// تمام عملیات CRUD و انتقال وضعیت اینجا شبیه‌سازی می‌شود تا رفتار UI
/// دقیقاً مانند نسخهٔ واقعی متصل به Backend باشد.
class CmsMockDataSource implements CmsDataSource {
  // یک نمونهٔ singleton تا تغییرات بین بازدیدهای مختلف صفحه حفظ شود.
  static final CmsMockDataSource _instance = CmsMockDataSource._internal();
  factory CmsMockDataSource() => _instance;
  CmsMockDataSource._internal();

  final List<CmsBookRow> _books = [
    CmsBookRow(
      id: 'b1',
      title: 'ریاضی صنف نهم',
      category: 'کتاب درسی رسمی',
      author: 'وزارت معارف',
      grade: 'صنف نهم',
      chaptersCount: 8,
      description: 'کتاب درسی رسمی ریاضیات برای صنف نهم شامل جبر، هندسه و آمار مقدماتی.',
      status: ContentStatus.published,
      updatedAt: DateTime(2026, 6, 20),
    ),
    CmsBookRow(
      id: 'b2',
      title: 'فزیک صنف نهم',
      category: 'کتاب درسی رسمی',
      author: 'وزارت معارف',
      grade: 'صنف نهم',
      chaptersCount: 6,
      description: 'مبانی مکانیک، حرکت و نیرو مطابق نصاب رسمی.',
      status: ContentStatus.published,
      updatedAt: DateTime(2026, 6, 18),
    ),
    CmsBookRow(
      id: 'b3',
      title: 'داستان‌های کوتاه دری',
      category: 'داستان',
      author: 'گروه محتوای مکتب',
      grade: 'عمومی',
      chaptersCount: 12,
      description: 'مجموعه‌ای از داستان‌های کوتاه برای تقویت مهارت خواندن.',
      status: ContentStatus.draft,
      updatedAt: DateTime(2026, 7, 1),
    ),
  ];

  final List<CmsLessonRow> _lessons = [
    CmsLessonRow(
      id: 'l1',
      title: 'معادلات درجهٔ دوم',
      gradeNumber: 9,
      subjectId: 'math',
      chapterTitle: 'فصل ۳: معادلات',
      durationMinutes: 35,
      content: 'تعریف معادلهٔ درجهٔ دوم، روش‌های حل (فاکتورگیری، فرمول عمومی) و مثال‌های کاربردی.',
      status: ContentStatus.published,
      updatedAt: DateTime(2026, 6, 22),
    ),
    CmsLessonRow(
      id: 'l2',
      title: 'حرکت نیوتنی',
      gradeNumber: 9,
      subjectId: 'physics',
      chapterTitle: 'فصل ۲: حرکت',
      durationMinutes: 40,
      content: 'قوانین سه‌گانهٔ نیوتن و کاربرد آن‌ها در حل مسائل حرکت.',
      status: ContentStatus.draft,
      updatedAt: DateTime(2026, 7, 2),
    ),
  ];

  final List<CmsQuestionRow> _questions = [
    CmsQuestionRow(
      id: 'q1',
      text: 'مجموع زوایای مثلث چند درجه است؟',
      difficulty: 'easy',
      subject: 'ریاضی',
      type: 'mcq',
      options: const ['۹۰', '۱۸۰', '۲۷۰', '۳۶۰'],
      answer: '۱۸۰',
      status: ContentStatus.published,
      updatedAt: DateTime(2026, 6, 25),
    ),
    CmsQuestionRow(
      id: 'q2',
      text: 'قانون دوم نیوتن را بنویسید و یک مثال بزنید.',
      difficulty: 'medium',
      subject: 'فزیک',
      type: 'essay',
      options: const [],
      answer: 'F = m × a',
      status: ContentStatus.approved,
      updatedAt: DateTime(2026, 6, 28),
    ),
  ];

  String _newId(String prefix) => '$prefix${DateTime.now().microsecondsSinceEpoch}';

  // ─────────────────────────── BOOKS ───────────────────────────
  @override
  Future<List<CmsBookRow>> getBooks() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final list = [..._books]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<CmsBookRow> saveBook(CmsBookRow row) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final idx = _books.indexWhere((b) => b.id == row.id);
    final saved = row.copyWith(updatedAt: DateTime.now());
    if (idx == -1) {
      final created = CmsBookRow(
        id: _newId('b'),
        title: saved.title,
        category: saved.category,
        author: saved.author,
        grade: saved.grade,
        chaptersCount: saved.chaptersCount,
        description: saved.description,
        status: saved.status,
        updatedAt: saved.updatedAt,
      );
      _books.add(created);
      return created;
    }
    _books[idx] = saved;
    return saved;
  }

  @override
  Future<void> deleteBook(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _books.removeWhere((b) => b.id == id);
  }

  @override
  Future<void> setBookStatus(String id, ContentStatus status) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx != -1) _books[idx] = _books[idx].copyWith(status: status, updatedAt: DateTime.now());
  }

  // ─────────────────────────── LESSONS ───────────────────────────
  @override
  Future<List<CmsLessonRow>> getLessons() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final list = [..._lessons]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<CmsLessonRow> saveLesson(CmsLessonRow row) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final idx = _lessons.indexWhere((l) => l.id == row.id);
    final saved = row.copyWith(updatedAt: DateTime.now());
    if (idx == -1) {
      final created = CmsLessonRow(
        id: _newId('l'),
        title: saved.title,
        gradeNumber: saved.gradeNumber,
        subjectId: saved.subjectId,
        chapterTitle: saved.chapterTitle,
        durationMinutes: saved.durationMinutes,
        content: saved.content,
        status: saved.status,
        updatedAt: saved.updatedAt,
      );
      _lessons.add(created);
      return created;
    }
    _lessons[idx] = saved;
    return saved;
  }

  @override
  Future<void> deleteLesson(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _lessons.removeWhere((l) => l.id == id);
  }

  @override
  Future<void> setLessonStatus(String id, ContentStatus status) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _lessons.indexWhere((l) => l.id == id);
    if (idx != -1) _lessons[idx] = _lessons[idx].copyWith(status: status, updatedAt: DateTime.now());
  }

  // ─────────────────────────── QUESTIONS ───────────────────────────
  @override
  Future<List<CmsQuestionRow>> getQuestions() async {
    await Future.delayed(const Duration(milliseconds: 250));
    final list = [..._questions]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  @override
  Future<CmsQuestionRow> saveQuestion(CmsQuestionRow row) async {
    await Future.delayed(const Duration(milliseconds: 250));
    final idx = _questions.indexWhere((q) => q.id == row.id);
    final saved = row.copyWith(updatedAt: DateTime.now());
    if (idx == -1) {
      final created = CmsQuestionRow(
        id: _newId('q'),
        text: saved.text,
        difficulty: saved.difficulty,
        subject: saved.subject,
        type: saved.type,
        options: saved.options,
        answer: saved.answer,
        status: saved.status,
        updatedAt: saved.updatedAt,
      );
      _questions.add(created);
      return created;
    }
    _questions[idx] = saved;
    return saved;
  }

  @override
  Future<void> deleteQuestion(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _questions.removeWhere((q) => q.id == id);
  }

  @override
  Future<void> setQuestionStatus(String id, ContentStatus status) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _questions.indexWhere((q) => q.id == id);
    if (idx != -1) _questions[idx] = _questions[idx].copyWith(status: status, updatedAt: DateTime.now());
  }

  // ─────────────────────────── INVITE CODES ───────────────────────────
  // منبع واحد حقیقت: `StudentInviteStore` — همان انباری که صفحهٔ راجستر
  // شاگرد کدها را در آن اعتبارسنجی/مصرف می‌کند. بنابراین کدی که مدیر
  // می‌سازد واقعاً در راجستر کار می‌کند، مصرفش اینجا «استفاده‌شده» می‌شود
  // (با نام شاگرد)، و ابطال مدیر بلافاصله کد را در راجستر بی‌اعتبار می‌کند.

  /// نگاشت کد دعوت استاد (`InstructorInviteStore`) به همان شکل عمومی —
  /// تا تب «کدهای استادان» از همین مسیر واحد (repository → usecase →
  /// provider) بگذرد و دیگر مستقیماً Store را در Widget صدا نزند.
  CmsInviteCodeRow _instructorRow(InstructorInviteCode c) => CmsInviteCodeRow(
        id: c.id,
        code: c.code,
        batchLabel: c.label,
        status: switch (c.status) {
          InstructorCodeStatus.used => 'used',
          InstructorCodeStatus.revoked => 'revoked',
          InstructorCodeStatus.unused => c.expired ? 'expired' : 'unused',
        },
        createdAt: c.createdAt,
        usedByName: c.usedByName,
        expiresAt: c.expiresAt,
      );

  CmsInviteCodeRow _toRow(StudentInviteCode c) => CmsInviteCodeRow(
        id: c.id,
        code: c.code,
        batchLabel: c.batchLabel,
        status: switch (c.status) {
          StudentCodeStatus.used => 'used',
          StudentCodeStatus.revoked => 'revoked',
          StudentCodeStatus.unused => c.expired ? 'expired' : 'unused',
        },
        createdAt: c.createdAt,
        usedByName: c.usedByName,
        expiresAt: c.expiresAt,
      );

  @override
  Future<List<CmsInviteCodeRow>> getInviteCodes({String type = 'student'}) async {
    await Future.delayed(const Duration(milliseconds: 250));
    if (type == 'instructor') {
      return InstructorInviteStore.instance.codes.map(_instructorRow).toList();
    }
    return StudentInviteStore.instance.codes.map(_toRow).toList();
  }

  /// طبق بخش ۳ب.۳ سند: صدور دسته‌ای Invite Code با `batch_label`.
  /// تولید کد در Store با `Random.secure()` و الفبای بدون ابهام انجام
  /// می‌شود؛ اعتبار پیش‌فرض هر کد ۳۰ روز است.
  @override
  Future<void> generateInviteCodes(int count, String batchLabel, {String type = 'student'}) async {
    await Future.delayed(const Duration(milliseconds: 350));
    if (type == 'instructor') {
      // کد استاد یکی‌یکی و برای یک شخص مشخص ساخته می‌شود (برچسب = نام/تخصص).
      for (var i = 0; i < count; i++) {
        InstructorInviteStore.instance.issueCode(label: batchLabel);
      }
      return;
    }
    StudentInviteStore.instance.generateBatch(count, batchLabel);
  }

  @override
  Future<void> revokeInviteCode(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // شناسهٔ کد استاد و شاگرد فضای نام جداگانه دارند («inst-» / معمولاً غیرِآن)،
    // پس امتحان هر دو انبار بی‌خطر است — فقط همان‌جایی که واقعاً وجود دارد اثر می‌کند.
    StudentInviteStore.instance.revoke(id);
    InstructorInviteStore.instance.revoke(id);
  }
}
