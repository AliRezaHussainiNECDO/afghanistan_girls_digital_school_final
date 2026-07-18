import 'dart:async';

import '../../../core/network/api_client.dart';
import '../domain/academy_entities.dart';
import 'academy_remote_datasource.dart';

/// انبار مرکزی و مشترک داده‌های آموزشی (کتاب‌ها، بانک سؤال، شاگردان، پاسخ‌ها).
///
/// یک singleton است که از فاز ۲ به بعد با سرور همگام می‌شود:
///  • `configure()` کلاینت API را می‌دهد و `hydrate()` داده را از سرور می‌خواند،
///  • هر تغییر (Write) هم در حافظه و هم روی سرور اعمال می‌شود (Write-through)،
/// بنابراین API همگام (sync) این کلاس دست‌نخورده می‌ماند و هیچ صفحه‌ای نیاز به
/// تغییر ندارد، اما داده‌ها روی سرور ماندگار و بین همهٔ کاربران مشترک‌اند.
class AcademyStore {
  static final AcademyStore _instance = AcademyStore._internal();
  factory AcademyStore() => _instance;
  AcademyStore._internal();

  String _id(String p) => '$p${DateTime.now().microsecondsSinceEpoch}';

  // ───────────────────── همگام‌سازی با سرور (Write-through) ─────────────────
  AcademyRemoteDataSource? _remote;
  bool _hydrated = false;

  /// اتصال به سرور (فقط در حالت Live صدا زده می‌شود).
  void configure(ApiClient api) {
    _remote ??= AcademyRemoteDataSource(api);
  }

  /// بارگذاری داده از سرور به کش محلی. یک‌بار کافی است؛ `force` برای تازه‌سازی.
  ///
  /// **اصلاح:** قبلاً هر خطای شبکه/سرور کاملاً فرونشانده می‌شد و کاربر همیشه
  /// دادهٔ نمونهٔ محلیِ ثابت (کتاب‌های آزمایشی) را می‌دید — بدون هیچ نشانه‌ای
  /// که این دادهٔ واقعی نیست. اکنون فقط اگر پیش‌تر **هرگز** با موفقیت از
  /// سرور خوانده نشده، خطا بالا پرتاب می‌شود تا صفحه پیام خطا/تلاش دوباره
  /// نشان دهد (طبق الگوی `ErrorView` موجود در بقیهٔ اپ). اگر قبلاً یک‌بار
  /// موفق شده و این فقط یک تازه‌سازیِ بعدی است، یک وقفهٔ کوتاه شبکه دادهٔ
  /// خوبِ قبلی را پاک نمی‌کند (خطا فرونشانده می‌شود).
  Future<void> hydrate({bool force = false}) async {
    final r = _remote;
    if (r == null || (_hydrated && !force)) return;
    try {
      final books = await r.fetchBooks();
      final questions = await r.fetchQuestions();
      final subs = await r.fetchSubmissions();
      _books
        ..clear()
        ..addAll(books);
      _questions
        ..clear()
        ..addAll(questions);
      _submissions
        ..clear()
        ..addAll(subs);
      _hydrated = true;
    } catch (_) {
      if (!_hydrated) rethrow;
    }
  }

  /// ارسال یک تغییر به سرور به‌صورت آتش‌وفراموش (خطا فرونشانده می‌شود؛
  /// hydrate بعدی سرور را منبع حقیقت می‌کند).
  void _push(Future<void> Function(AcademyRemoteDataSource r) op) {
    final r = _remote;
    if (r == null) return;
    unawaited(op(r).catchError((_) {}));
  }

  // ───────────────────────── شاگردان ─────────────────────────
  final List<StudentProfile> _students = const [
    StudentProfile(id: 'st1', displayName: 'زهرا احمدی', gradeIds: [9]),
    StudentProfile(id: 'st2', displayName: 'مریم نوری', gradeIds: [8, 9]),
    StudentProfile(id: 'st3', displayName: 'فاطمه رضایی', gradeIds: [7]),
    StudentProfile(id: 'st4', displayName: 'سمیرا حسینی', gradeIds: [10, 11]),
  ];

  List<StudentProfile> getStudents() => List.unmodifiable(_students);
  StudentProfile studentById(String id) =>
      _students.firstWhere((s) => s.id == id, orElse: () => _students.first);

  // ───────────────────────── کتاب‌ها ─────────────────────────
  final List<LibraryBook> _books = [
    LibraryBook(
      id: 'lb1',
      title: 'ریاضی صنف نهم',
      subject: 'ریاضی',
      gradeId: 9,
      category: 'کتاب درسی رسمی',
      author: 'وزارت معارف',
      description: 'کتاب درسی رسمی ریاضیات صنف نهم شامل جبر، هندسه و آمار مقدماتی.',
      pdfFileName: 'math_9.pdf',
      pdfPath: '',
      fileSizeMb: 12.4,
      pageCount: 168,
      coverIndex: 0,
      includeInRag: true,
      status: PublishStatus.published,
      uploadedAt: DateTime(2026, 6, 10),
      updatedAt: DateTime(2026, 6, 20),
    ),
    LibraryBook(
      id: 'lb2',
      title: 'فزیک صنف نهم',
      subject: 'فزیک',
      gradeId: 9,
      category: 'کتاب درسی رسمی',
      author: 'وزارت معارف',
      description: 'مبانی مکانیک، حرکت و نیرو مطابق نصاب رسمی.',
      pdfFileName: 'physics_9.pdf',
      fileSizeMb: 15.7,
      pageCount: 142,
      coverIndex: 2,
      includeInRag: true,
      status: PublishStatus.published,
      uploadedAt: DateTime(2026, 6, 12),
      updatedAt: DateTime(2026, 6, 18),
    ),
    LibraryBook(
      id: 'lb3',
      title: 'داستان‌های کوتاه دری',
      subject: 'ادبیات دری',
      gradeId: 0,
      category: 'داستان',
      author: 'گروه محتوای مکتب',
      description: 'مجموعه‌ای از داستان‌های کوتاه برای تقویت مهارت خواندن.',
      fileSizeMb: 3.1,
      pageCount: 54,
      coverIndex: 4,
      status: PublishStatus.draft,
      uploadedAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
    ),
  ];

  /// [gradeIds] رفع اشکال: قبلاً کتابخانهٔ شاگرد هیچ فیلتر صنفی نداشت — یک
  /// شاگرد صنف هفتم عیناً کتاب‌های صنف دوازدهم را هم می‌دید. اکنون اگر
  /// فهرست صنوف داده شود، فقط کتاب‌های «عمومی» (gradeId=0) + همان صنف(ها)
  /// نمایش داده می‌شوند. اگر null/خالی باشد (مثلاً نمای مدیر)، فیلتر نمی‌شود.
  List<LibraryBook> getBooks({bool publishedOnly = false, String query = '', List<int>? gradeIds}) {
    var list = _books.where((b) => !publishedOnly || b.status == PublishStatus.published);
    if (gradeIds != null && gradeIds.isNotEmpty) {
      list = list.where((b) => b.gradeId == 0 || gradeIds.contains(b.gradeId));
    }
    if (query.trim().isNotEmpty) {
      final q = query.trim();
      list = list.where((b) =>
          b.title.contains(q) || b.subject.contains(q) || b.author.contains(q) || b.category.contains(q));
    }
    final result = list.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  LibraryBook saveBook(LibraryBook row) {
    final idx = _books.indexWhere((b) => b.id == row.id);
    final stamped = row.copyWith(updatedAt: DateTime.now());
    if (idx == -1) {
      final created = LibraryBook(
        id: _id('lb'),
        title: stamped.title,
        subject: stamped.subject,
        gradeId: stamped.gradeId,
        category: stamped.category,
        author: stamped.author,
        description: stamped.description,
        language: stamped.language,
        pdfFileName: stamped.pdfFileName,
        pdfPath: stamped.pdfPath,
        pdfKey: stamped.pdfKey,
        fileSizeMb: stamped.fileSizeMb,
        pageCount: stamped.pageCount,
        coverIndex: stamped.coverIndex,
        includeInRag: stamped.includeInRag,
        status: stamped.status,
        uploadedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _books.add(created);
      _push((r) => r.upsertBook(created));
      return created;
    }
    _books[idx] = stamped;
    _push((r) => r.upsertBook(stamped));
    return stamped;
  }

  /// مثل [saveBook] (کش محلی را فوراً به‌روز می‌کند)، اما علاوه بر آن تا
  /// پایان واقعیِ نوشتن روی سرور هم صبر می‌کند. لازم است وقتی بلافاصله پس
  /// از ذخیره باید عملیات دیگری انجام شود که به وجود واقعیِ ردیف روی سرور
  /// نیاز دارد (مثلاً آپلود فایل پی‌دی‌افِ همان کتاب — در غیر این صورت،
  /// چون [saveBook] نوشتن سرور را «آتش‌وفراموش» انجام می‌دهد، ممکن است
  /// آپلود زودتر از تکمیل ساخت ردیف برسد و با خطای «کتاب یافت نشد» مواجه
  /// شود). خطای شبکه اینجا برخلاف [saveBook] بالا پرتاب می‌شود تا UI واقعاً
  /// بداند ذخیره ناموفق بوده.
  Future<LibraryBook> saveBookAwaitingServer(LibraryBook row) async {
    final saved = saveBook(row);
    final r = _remote;
    if (r != null) {
      await r.upsertBook(saved);
    }
    return saved;
  }

  void deleteBook(String id) {
    _books.removeWhere((b) => b.id == id);
    _push((r) => r.deleteBook(id));
  }

  void setBookStatus(String id, PublishStatus status) {
    final idx = _books.indexWhere((b) => b.id == id);
    if (idx != -1) {
      _books[idx] = _books[idx].copyWith(status: status);
      _push((r) => r.upsertBook(_books[idx]));
    }
  }

  /// آپلود واقعیِ فایل پی‌دی‌اف یک کتاب (منتظر پاسخ سرور می‌ماند — برخلاف
  /// بقیهٔ نوشتن‌های این کلاس که «آتش‌وفراموش»‌اند — چون UI باید تا پایان
  /// واقعیِ آپلود صبر کند و پیشرفت/خطا را نشان دهد).
  Future<LibraryBook?> uploadBookPdf(String bookId, List<int> bytes, String fileName) async {
    final r = _remote;
    if (r == null) return null;
    final result = await r.uploadBookPdf(bookId, bytes, fileName);
    final idx = _books.indexWhere((b) => b.id == bookId);
    if (idx == -1) return null;
    final sizeMb = double.parse((bytes.length / (1024 * 1024)).toStringAsFixed(1));
    final updated = _books[idx].copyWith(
      pdfFileName: fileName,
      pdfKey: (result['pdfKey'] ?? '').toString(),
      fileSizeMb: sizeMb,
      updatedAt: DateTime.now(),
    );
    _books[idx] = updated;
    return updated;
  }

  /// دانلود واقعیِ بایت‌های فایل یک کتاب (برای شاگرد).
  Future<List<int>?> downloadBookPdf(String pdfKey) async {
    final r = _remote;
    if (r == null || pdfKey.isEmpty) return null;
    return r.downloadBookPdf(pdfKey);
  }

  // ───────────────────────── بانک سؤالات ─────────────────────────
  final List<BankQuestion> _questions = [
    BankQuestion(
      id: 'bq1',
      subject: 'ریاضی',
      gradeId: 9,
      chapter: 'فصل ۳ — معادلات',
      kind: QuestionKind.mcq,
      text: 'مجموع زوایای داخلی یک مثلث چند درجه است؟',
      options: const ['۹۰', '۱۸۰', '۲۷۰', '۳۶۰'],
      correctIndex: 1,
      points: 1,
      status: PublishStatus.published,
      createdAt: DateTime(2026, 6, 25),
    ),
    BankQuestion(
      id: 'bq2',
      subject: 'ریاضی',
      gradeId: 9,
      chapter: 'فصل ۳ — معادلات',
      kind: QuestionKind.trueFalse,
      text: 'معادلهٔ درجهٔ دوم همیشه دو ریشهٔ حقیقی دارد.',
      correctBool: false,
      points: 1,
      status: PublishStatus.published,
      createdAt: DateTime(2026, 6, 26),
    ),
    BankQuestion(
      id: 'bq3',
      subject: 'فزیک',
      gradeId: 9,
      chapter: 'فصل ۲ — حرکت',
      kind: QuestionKind.essay,
      text: 'قانون دوم نیوتن را توضیح دهید و یک مثال از زندگی روزمره بزنید.',
      modelAnswer: 'نیرو برابر است با جرم ضرب در شتاب (F=ma). مثال: هل دادن یک چرخ‌دستی.',
      points: 5,
      status: PublishStatus.published,
      createdAt: DateTime(2026, 6, 28),
    ),
    // ── امتحان صنف ۷ (ریاضی) — برای شاگرد نمایشی ──
    BankQuestion(
      id: 'bq7a',
      subject: 'ریاضی',
      gradeId: 7,
      chapter: 'فصل ۱ — اعداد',
      kind: QuestionKind.mcq,
      text: 'حاصل ۷ × ۸ چند است؟',
      options: const ['۴۹', '۵۶', '۶۳', '۶۴'],
      correctIndex: 1,
      points: 1,
      status: PublishStatus.published,
      createdAt: DateTime(2026, 7, 1),
    ),
    BankQuestion(
      id: 'bq7b',
      subject: 'ریاضی',
      gradeId: 7,
      chapter: 'فصل ۱ — اعداد',
      kind: QuestionKind.trueFalse,
      text: 'عدد ۱۷ یک عدد اول است.',
      correctBool: true,
      points: 1,
      status: PublishStatus.published,
      createdAt: DateTime(2026, 7, 1),
    ),
    BankQuestion(
      id: 'bq7c',
      subject: 'ریاضی',
      gradeId: 7,
      chapter: 'فصل ۲ — کسرها',
      kind: QuestionKind.mcq,
      text: 'حاصل ۱/۲ + ۱/۴ چند است؟',
      options: const ['۱/۶', '۲/۶', '۳/۴', '۱/۸'],
      correctIndex: 2,
      points: 1,
      status: PublishStatus.published,
      createdAt: DateTime(2026, 7, 1),
    ),
  ];

  List<BankQuestion> getQuestions({
    bool publishedOnly = false,
    String subject = '',
    int? gradeId,
    String query = '',
  }) {
    var list = _questions.where((q) => !publishedOnly || q.status == PublishStatus.published);
    if (subject.isNotEmpty) list = list.where((q) => q.subject == subject);
    if (gradeId != null) list = list.where((q) => q.gradeId == gradeId);
    if (query.trim().isNotEmpty) {
      final s = query.trim();
      list = list.where((q) => q.text.contains(s) || q.subject.contains(s) || q.chapter.contains(s));
    }
    final result = list.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return result;
  }

  BankQuestion saveQuestion(BankQuestion row) {
    final idx = _questions.indexWhere((q) => q.id == row.id);
    if (idx == -1) {
      final created = BankQuestion(
        id: _id('bq'),
        subject: row.subject,
        gradeId: row.gradeId,
        chapter: row.chapter,
        kind: row.kind,
        text: row.text,
        options: row.options,
        correctIndex: row.correctIndex,
        correctBool: row.correctBool,
        modelAnswer: row.modelAnswer,
        points: row.points,
        status: row.status,
        aiGenerated: row.aiGenerated,
        createdAt: DateTime.now(),
      );
      _questions.add(created);
      _push((r) => r.upsertQuestion(created));
      return created;
    }
    _questions[idx] = row;
    _push((r) => r.upsertQuestion(row));
    return row;
  }

  /// افزودن دسته‌ای (مثلاً خروجی هوش مصنوعی) — همه به‌صورت پیش‌نویس.
  void addQuestions(Iterable<BankQuestion> rows) {
    for (final r in rows) {
      final created = BankQuestion(
        id: _id('bq'),
        subject: r.subject,
        gradeId: r.gradeId,
        chapter: r.chapter,
        kind: r.kind,
        text: r.text,
        options: r.options,
        correctIndex: r.correctIndex,
        correctBool: r.correctBool,
        modelAnswer: r.modelAnswer,
        points: r.points,
        status: r.status,
        aiGenerated: r.aiGenerated,
        createdAt: DateTime.now(),
      );
      _questions.add(created);
      _push((rem) => rem.upsertQuestion(created));
    }
  }

  void deleteQuestion(String id) {
    _questions.removeWhere((q) => q.id == id);
    _push((r) => r.deleteQuestion(id));
  }

  void setQuestionStatus(String id, PublishStatus status) {
    final idx = _questions.indexWhere((q) => q.id == id);
    if (idx != -1) {
      _questions[idx] = _questions[idx].copyWith(status: status);
      _push((r) => r.upsertQuestion(_questions[idx]));
    }
  }

  /// فهرست فصل‌های موجود برای یک مضمون+صنف (برای انتخاب در تولید سؤال).
  List<String> chaptersFor(String subject, int gradeId) {
    // فصل‌ها در این فاز از سؤالات موجود همان مضمون/صنف استخراج می‌شوند.
    final set = <String>{};
    for (final q in _questions) {
      if (q.subject == subject && (gradeId == 0 || q.gradeId == gradeId) && q.chapter.isNotEmpty) {
        set.add(q.chapter);
      }
    }
    return set.toList()..sort();
  }

  // ───────────────────────── امتحانات (مشتق) ─────────────────────────
  /// لیست امتحانات موجود برای شاگرد بر اساس سؤالات منتشرشده. اگر gradeIds
  /// داده شود، فقط امتحانات آن صنوف برگردانده می‌شود.
  List<SubjectExam> getSubjectExams({List<int>? gradeIds}) {
    final map = <String, List<BankQuestion>>{};
    for (final q in _questions.where((q) => q.status == PublishStatus.published)) {
      if (gradeIds != null && gradeIds.isNotEmpty && !gradeIds.contains(q.gradeId)) continue;
      map.putIfAbsent('${q.subject}#${q.gradeId}', () => []).add(q);
    }
    final exams = map.entries.map((e) {
      final qs = e.value;
      return SubjectExam(
        subject: qs.first.subject,
        gradeId: qs.first.gradeId,
        questionCount: qs.length,
        totalPoints: qs.fold(0, (s, q) => s + q.points),
      );
    }).toList();
    exams.sort((a, b) {
      final g = a.gradeId.compareTo(b.gradeId);
      return g != 0 ? g : a.subject.compareTo(b.subject);
    });
    return exams;
  }

  List<BankQuestion> getExamQuestions(String subject, int gradeId) {
    final list = _questions
        .where((q) => q.status == PublishStatus.published && q.subject == subject && q.gradeId == gradeId)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return list;
  }

  // ───────────────────────── پاسخ‌ها (Submissions) ─────────────────────────
  final List<Submission> _submissions = [];

  Submission saveSubmission(Submission s) {
    final withId = Submission(
      id: _id('sub'),
      studentId: s.studentId,
      studentName: s.studentName,
      gradeId: s.gradeId,
      subject: s.subject,
      submittedAt: DateTime.now(),
      answers: s.answers,
      scorePercent: s.scorePercent,
      earnedPoints: s.earnedPoints,
      totalPoints: s.totalPoints,
      aiAssisted: s.aiAssisted,
    );
    _submissions.insert(0, withId);
    _push((r) => r.createSubmission(withId));
    return withId;
  }

  List<Submission> getSubmissions({String? studentId, int? gradeId, String? subject}) {
    var list = _submissions.where((s) =>
        (studentId == null || s.studentId == studentId) &&
        (gradeId == null || s.gradeId == gradeId) &&
        (subject == null || s.subject == subject));
    return list.toList()..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
  }
}
