import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../domain/academy_entities.dart';

/// دیتاسورس سرور آکادمی — کتابخانه، بانک سؤال و پاسخ‌ها روی `/api/v1/academy/*`.
/// نگاشت Entity ↔ JSON این‌جا انجام می‌شود تا Entity ها ساده بمانند.
class AcademyRemoteDataSource {
  final ApiClient _api;
  AcademyRemoteDataSource(this._api);

  Map<String, dynamic> _map(dynamic d) =>
      d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map);

  // ─────────────────────────────── Books ───────────────────────────────────

  Future<List<LibraryBook>> fetchBooks() async {
    final data = _map(await _api.get('/academy/books'));
    return (data['books'] as List? ?? []).map((e) => _bookFromJson(_map(e))).toList();
  }

  Future<void> upsertBook(LibraryBook b) async {
    await _api.post('/academy/books', data: _bookToJson(b));
  }

  Future<void> deleteBook(String id) async {
    await _api.delete('/academy/books/$id');
  }

  /// آپلود واقعیِ فایل پی‌دی‌اف روی سرور (R2) — قبلاً این مرحله کاملاً
  /// شبیه‌سازی بود. بدنه = بایت‌های خام؛ نام فایل در Query String.
  Future<Map<String, dynamic>> uploadBookPdf(String bookId, List<int> bytes, String fileName) async {
    final data = await _api.post(
      '/academy/books/$bookId/pdf',
      data: Stream<List<int>>.value(bytes),
      queryParameters: {'fileName': fileName},
      options: Options(
        contentType: 'application/pdf',
        headers: {Headers.contentLengthHeader: bytes.length},
      ),
    );
    return _map(data);
  }

  /// دانلود واقعیِ بایت‌های فایل از `GET /files/{pdfKey}` — قبلاً شاگرد هیچ
  /// فایل واقعی دریافت نمی‌کرد (فقط یک تأخیر مصنوعی + پیام موفقیت جعلی).
  Future<List<int>> downloadBookPdf(String pdfKey) async {
    final data = await _api.get(
      '/files/$pdfKey',
      options: Options(responseType: ResponseType.bytes),
    );
    if (data is List<int>) return data;
    return const [];
  }

  // ───────────────────────────── Questions ─────────────────────────────────

  Future<List<BankQuestion>> fetchQuestions() async {
    final data = _map(await _api.get('/academy/questions'));
    return (data['questions'] as List? ?? []).map((e) => _questionFromJson(_map(e))).toList();
  }

  Future<void> upsertQuestion(BankQuestion q) async {
    await _api.post('/academy/questions', data: _questionToJson(q));
  }

  Future<void> deleteQuestion(String id) async {
    await _api.delete('/academy/questions/$id');
  }

  // ──────────────────────────── Submissions ────────────────────────────────

  Future<List<Submission>> fetchSubmissions({String? studentId}) async {
    final data = _map(await _api.get('/academy/submissions',
        queryParameters: {if (studentId != null) 'studentId': studentId}));
    return (data['submissions'] as List? ?? []).map((e) => _submissionFromJson(_map(e))).toList();
  }

  Future<void> createSubmission(Submission s) async {
    await _api.post('/academy/submissions', data: _submissionToJson(s));
  }

  // ─────────────────────────── نگاشت‌ها (Book) ──────────────────────────────

  Map<String, dynamic> _bookToJson(LibraryBook b) => {
        'id': b.id,
        'title': b.title,
        'subject': b.subject,
        'gradeId': b.gradeId,
        'category': b.category,
        'author': b.author,
        'description': b.description,
        'language': b.language,
        'pdfFileName': b.pdfFileName,
        'pdfKey': b.pdfKey,
        'fileSizeMb': b.fileSizeMb,
        'pageCount': b.pageCount,
        'coverIndex': b.coverIndex,
        'includeInRag': b.includeInRag,
        'status': b.status.key,
      };

  LibraryBook _bookFromJson(Map<String, dynamic> j) => LibraryBook(
        id: (j['id'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        gradeId: (j['gradeId'] as num?)?.toInt() ?? 0,
        category: (j['category'] ?? '').toString(),
        author: (j['author'] ?? '').toString(),
        description: (j['description'] ?? '').toString(),
        language: (j['language'] ?? 'دری').toString(),
        pdfFileName: (j['pdfFileName'] ?? '').toString(),
        pdfKey: (j['pdfKey'] ?? '').toString(),
        fileSizeMb: (j['fileSizeMb'] as num?)?.toDouble() ?? 0,
        pageCount: (j['pageCount'] as num?)?.toInt() ?? 0,
        coverIndex: (j['coverIndex'] as num?)?.toInt() ?? 0,
        includeInRag: j['includeInRag'] == true,
        status: PublishStatusX.fromKey((j['status'] ?? 'draft').toString()),
        uploadedAt: DateTime.tryParse((j['uploadedAt'] ?? '').toString()) ?? DateTime.now(),
        updatedAt: DateTime.tryParse((j['updatedAt'] ?? '').toString()) ?? DateTime.now(),
      );

  // ─────────────────────────── نگاشت‌ها (Question) ──────────────────────────

  Map<String, dynamic> _questionToJson(BankQuestion q) => {
        'id': q.id,
        'subject': q.subject,
        'gradeId': q.gradeId,
        'chapter': q.chapter,
        'kind': q.kind.key,
        'text': q.text,
        'options': q.options,
        'correctIndex': q.correctIndex,
        'correctBool': q.correctBool,
        'modelAnswer': q.modelAnswer,
        'points': q.points,
        'status': q.status.key,
        'aiGenerated': q.aiGenerated,
      };

  BankQuestion _questionFromJson(Map<String, dynamic> j) => BankQuestion(
        id: (j['id'] ?? '').toString(),
        subject: (j['subject'] ?? '').toString(),
        gradeId: (j['gradeId'] as num?)?.toInt() ?? 0,
        chapter: (j['chapter'] ?? '').toString(),
        kind: QuestionKindX.fromKey((j['kind'] ?? 'mcq').toString()),
        text: (j['text'] ?? '').toString(),
        options: (j['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        correctIndex: (j['correctIndex'] as num?)?.toInt() ?? 0,
        correctBool: j['correctBool'] == true,
        modelAnswer: (j['modelAnswer'] ?? '').toString(),
        points: (j['points'] as num?)?.toInt() ?? 1,
        status: PublishStatusX.fromKey((j['status'] ?? 'draft').toString()),
        aiGenerated: j['aiGenerated'] == true,
        createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString()) ?? DateTime.now(),
      );

  // ────────────────────────── نگاشت‌ها (Submission) ─────────────────────────

  Map<String, dynamic> _submissionToJson(Submission s) => {
        'id': s.id,
        'studentId': s.studentId,
        'studentName': s.studentName,
        'gradeId': s.gradeId,
        'subject': s.subject,
        'scorePercent': s.scorePercent,
        'earnedPoints': s.earnedPoints,
        'totalPoints': s.totalPoints,
        'aiAssisted': s.aiAssisted,
        'answers': s.answers.map(_answerToJson).toList(),
      };

  Submission _submissionFromJson(Map<String, dynamic> j) => Submission(
        id: (j['id'] ?? '').toString(),
        studentId: (j['studentId'] ?? '').toString(),
        studentName: (j['studentName'] ?? '').toString(),
        gradeId: (j['gradeId'] as num?)?.toInt() ?? 0,
        subject: (j['subject'] ?? '').toString(),
        submittedAt: DateTime.tryParse((j['submittedAt'] ?? '').toString()) ?? DateTime.now(),
        answers: (j['answers'] as List? ?? []).map((e) => _answerFromJson(_map(e))).toList(),
        scorePercent: (j['scorePercent'] as num?)?.toDouble() ?? 0,
        earnedPoints: (j['earnedPoints'] as num?)?.toDouble() ?? 0,
        totalPoints: (j['totalPoints'] as num?)?.toDouble() ?? 0,
        aiAssisted: j['aiAssisted'] == true,
      );

  Map<String, dynamic> _answerToJson(SubmissionAnswer a) => {
        'questionId': a.questionId,
        'questionText': a.questionText,
        'kind': a.kind.key,
        'options': a.options,
        'chosenIndex': a.chosenIndex,
        'chosenBool': a.chosenBool,
        'essayText': a.essayText,
        'correctIndex': a.correctIndex,
        'correctBool': a.correctBool,
        'modelAnswer': a.modelAnswer,
        'awardedPoints': a.awardedPoints,
        'maxPoints': a.maxPoints,
        'isCorrect': a.isCorrect,
        'aiFeedback': a.aiFeedback,
      };

  SubmissionAnswer _answerFromJson(Map<String, dynamic> j) => SubmissionAnswer(
        questionId: (j['questionId'] ?? '').toString(),
        questionText: (j['questionText'] ?? '').toString(),
        kind: QuestionKindX.fromKey((j['kind'] ?? 'mcq').toString()),
        options: (j['options'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        chosenIndex: (j['chosenIndex'] as num?)?.toInt(),
        chosenBool: j['chosenBool'] as bool?,
        essayText: j['essayText'] as String?,
        correctIndex: (j['correctIndex'] as num?)?.toInt(),
        correctBool: j['correctBool'] as bool?,
        modelAnswer: (j['modelAnswer'] ?? '').toString(),
        awardedPoints: (j['awardedPoints'] as num?)?.toDouble() ?? 0,
        maxPoints: (j['maxPoints'] as num?)?.toDouble() ?? 0,
        isCorrect: j['isCorrect'] as bool?,
        aiFeedback: (j['aiFeedback'] ?? '').toString(),
      );
}
