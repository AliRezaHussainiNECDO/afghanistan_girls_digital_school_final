import '../../../../core/network/api_client.dart';
import '../../domain/entities/curriculum_entities.dart';

/// قرارداد مشترک DataSource نصاب — هم Mock و هم Remote آن را پیاده می‌کنند
/// تا با یک سوییچ در Providerها تعویض شوند (اصل بخش ۲۴.۲ سند).
abstract class CurriculumDataSource {
  Future<List<Chapter>> getChapters(String subjectId);
  Future<List<Lesson>> getLessons(String chapterId);
  Future<Lesson> getLesson(String lessonId);
  Future<void> markLessonViewed(String lessonId);
}

/// پیاده‌سازی واقعی روی Backend (روتر curriculum زیر `/api/v1`).
///
/// [_grade] صنف فعال دانش‌آموز است؛ چون مسیر فلاتر `getChapters(subjectId)`
/// خودش صنف را حمل نمی‌کند، آن را از نشست کاربر می‌گیریم و به‌عنوان
/// Query به سرور می‌فرستیم (`?grade=`). Providerها با تغییر صنف، این
/// DataSource را دوباره می‌سازند.
class CurriculumRemoteDataSource implements CurriculumDataSource {
  final ApiClient _api;
  final int _grade;

  CurriculumRemoteDataSource(this._api, this._grade);

  @override
  Future<List<Chapter>> getChapters(String subjectId) async {
    final data = await _api.get('/subjects/$subjectId/chapters',
        queryParameters: {'grade': _grade});
    final list = (data['chapters'] as List? ?? []);
    return list
        .map((e) => Chapter(
              id: e['id'] as String,
              titleFa: e['title_fa'] as String,
              orderIndex: (e['order_index'] as num?)?.toInt() ?? 0,
              lessonCount: (e['lesson_count'] as num?)?.toInt() ?? 0,
            ))
        .toList();
  }

  @override
  Future<List<Lesson>> getLessons(String chapterId) async {
    final data = await _api.get('/chapters/$chapterId/lessons');
    final list = (data['lessons'] as List? ?? []);
    return list.map(_lessonFromJson).toList();
  }

  @override
  Future<Lesson> getLesson(String lessonId) async {
    final data = await _api.get('/lessons/$lessonId');
    return _lessonFromJson(data['lesson'] as Map);
  }

  @override
  Future<void> markLessonViewed(String lessonId) async {
    await _api.post('/lessons/$lessonId/view');
  }

  Lesson _lessonFromJson(dynamic e) => Lesson(
        id: e['id'] as String,
        chapterId: e['chapter_id'] as String,
        titleFa: e['title_fa'] as String,
        estimatedMinutes: (e['estimated_minutes'] as num?)?.toInt() ?? 15,
        viewed: (e['viewed'] as num?)?.toInt() == 1 || e['viewed'] == true,
        contentBody: (e['content_body'] as String?) ?? '',
      );
}
