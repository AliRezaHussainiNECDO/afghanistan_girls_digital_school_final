import '../../../../../core/network/api_client.dart';
import '../../domain/entities/cms_entities.dart';

/// قرارداد مشترک DataSource مدیریت محتوا (CMS) — Mock و Remote هر دو آن را
/// پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class CmsDataSource {
  Future<List<CmsBookRow>> getBooks();
  Future<CmsBookRow> saveBook(CmsBookRow row);
  Future<void> deleteBook(String id);
  Future<void> setBookStatus(String id, ContentStatus status);

  Future<List<CmsLessonRow>> getLessons();
  Future<CmsLessonRow> saveLesson(CmsLessonRow row);
  Future<void> deleteLesson(String id);
  Future<void> setLessonStatus(String id, ContentStatus status);

  Future<List<CmsQuestionRow>> getQuestions();
  Future<CmsQuestionRow> saveQuestion(CmsQuestionRow row);
  Future<void> deleteQuestion(String id);
  Future<void> setQuestionStatus(String id, ContentStatus status);

  Future<List<CmsInviteCodeRow>> getInviteCodes();
  Future<void> generateInviteCodes(int count, String batchLabel);
  Future<void> revokeInviteCode(String id);
}

/// پیاده‌سازی واقعی — روتر `/api/v1/admin/cms/*` (محتوا) و `/api/v1/admin/
/// invite-codes*` (کدهای دعوت). فقط مدیر (JWT با نقش super_admin).
class CmsRemoteDataSource implements CmsDataSource {
  final ApiClient _api;
  CmsRemoteDataSource(this._api);

  // ───────────────────────────── کتاب‌ها ─────────────────────────────

  @override
  Future<List<CmsBookRow>> getBooks() async {
    final data = await _api.get('/admin/cms/books');
    return ((data['books'] as List?) ?? []).map(_bookFrom).toList();
  }

  @override
  Future<CmsBookRow> saveBook(CmsBookRow row) async {
    final data = await _api.post('/admin/cms/books', data: {
      'id': row.id,
      'title': row.title,
      'category': row.category,
      'author': row.author,
      'grade': row.grade,
      'chaptersCount': row.chaptersCount,
      'description': row.description,
      'status': row.status.key,
    });
    return _bookFrom(data['book']);
  }

  @override
  Future<void> deleteBook(String id) => _api.delete('/admin/cms/books/$id');

  @override
  Future<void> setBookStatus(String id, ContentStatus status) =>
      _api.patch('/admin/cms/books/$id/status', data: {'status': status.key});

  // ────────────────────────────── دروس ───────────────────────────────

  @override
  Future<List<CmsLessonRow>> getLessons() async {
    final data = await _api.get('/admin/cms/lessons');
    return ((data['lessons'] as List?) ?? []).map(_lessonFrom).toList();
  }

  @override
  Future<CmsLessonRow> saveLesson(CmsLessonRow row) async {
    final data = await _api.post('/admin/cms/lessons', data: {
      'id': row.id,
      'title': row.title,
      'chapterTitle': row.chapterTitle,
      'bookTitle': row.bookTitle,
      'durationMinutes': row.durationMinutes,
      'content': row.content,
      'status': row.status.key,
    });
    return _lessonFrom(data['lesson']);
  }

  @override
  Future<void> deleteLesson(String id) => _api.delete('/admin/cms/lessons/$id');

  @override
  Future<void> setLessonStatus(String id, ContentStatus status) =>
      _api.patch('/admin/cms/lessons/$id/status', data: {'status': status.key});

  // ────────────────────────────── سؤالات ─────────────────────────────

  @override
  Future<List<CmsQuestionRow>> getQuestions() async {
    final data = await _api.get('/admin/cms/questions');
    return ((data['questions'] as List?) ?? []).map(_questionFrom).toList();
  }

  @override
  Future<CmsQuestionRow> saveQuestion(CmsQuestionRow row) async {
    final data = await _api.post('/admin/cms/questions', data: {
      'id': row.id,
      'text': row.text,
      'difficulty': row.difficulty,
      'subject': row.subject,
      'type': row.type,
      'options': row.options,
      'answer': row.answer,
      'status': row.status.key,
    });
    return _questionFrom(data['question']);
  }

  @override
  Future<void> deleteQuestion(String id) => _api.delete('/admin/cms/questions/$id');

  @override
  Future<void> setQuestionStatus(String id, ContentStatus status) =>
      _api.patch('/admin/cms/questions/$id/status', data: {'status': status.key});

  // ──────────────────── کدهای دعوت (روتر admin موجود) ─────────────────

  @override
  Future<List<CmsInviteCodeRow>> getInviteCodes() async {
    final data = await _api.get('/admin/invite-codes', queryParameters: {'type': 'student'});
    return ((data['inviteCodes'] as List?) ?? []).map(_inviteFrom).toList();
  }

  @override
  Future<void> generateInviteCodes(int count, String batchLabel) => _api.post(
        '/admin/invite-codes/bulk-generate',
        data: {'type': 'student', 'count': count, 'batchLabel': batchLabel},
      );

  @override
  Future<void> revokeInviteCode(String id) => _api.patch('/admin/invite-codes/$id/revoke');

  // ─────────────────────────── نگاشت JSON ────────────────────────────

  CmsBookRow _bookFrom(dynamic e) => CmsBookRow(
        id: e['id'] as String,
        title: e['title'] as String? ?? '',
        category: e['category'] as String? ?? '',
        author: e['author'] as String? ?? '',
        grade: e['grade'] as String? ?? '',
        chaptersCount: (e['chaptersCount'] as num?)?.toInt() ?? 0,
        description: e['description'] as String? ?? '',
        status: ContentStatusX.fromKey(e['status'] as String? ?? 'draft'),
        updatedAt: DateTime.tryParse(e['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  CmsLessonRow _lessonFrom(dynamic e) => CmsLessonRow(
        id: e['id'] as String,
        title: e['title'] as String? ?? '',
        chapterTitle: e['chapterTitle'] as String? ?? '',
        bookTitle: e['bookTitle'] as String? ?? '',
        durationMinutes: (e['durationMinutes'] as num?)?.toInt() ?? 0,
        content: e['content'] as String? ?? '',
        status: ContentStatusX.fromKey(e['status'] as String? ?? 'draft'),
        updatedAt: DateTime.tryParse(e['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  CmsQuestionRow _questionFrom(dynamic e) => CmsQuestionRow(
        id: e['id'] as String,
        text: e['text'] as String? ?? '',
        difficulty: e['difficulty'] as String? ?? 'medium',
        subject: e['subject'] as String? ?? '',
        type: e['type'] as String? ?? 'mcq',
        options: ((e['options'] as List?) ?? []).map((o) => o.toString()).toList(),
        answer: e['answer'] as String? ?? '',
        status: ContentStatusX.fromKey(e['status'] as String? ?? 'draft'),
        updatedAt: DateTime.tryParse(e['updatedAt'] as String? ?? '') ?? DateTime.now(),
      );

  CmsInviteCodeRow _inviteFrom(dynamic e) => CmsInviteCodeRow(
        id: e['id'] as String,
        code: e['code'] as String? ?? '',
        batchLabel: e['batchLabel'] as String? ?? '',
        status: e['status'] as String? ?? 'unused',
        createdAt: DateTime.tryParse(e['createdAt'] as String? ?? '') ?? DateTime.now(),
        expiresAt: DateTime.tryParse(e['expiresAt'] as String? ?? ''),
      );
}
