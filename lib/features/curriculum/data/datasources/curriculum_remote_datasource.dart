import '../../../../core/network/api_client.dart';
import '../../domain/entities/curriculum_entities.dart';

abstract class CurriculumDataSource {
  Future<List<Chapter>> getChapters(String subjectId);
  Future<List<Lesson>> getLessons(String chapterId);
  Future<Lesson> getLesson(String lessonId);
  Future<LessonViewResult> markLessonViewed(String lessonId);
}

class CurriculumRemoteDataSource implements CurriculumDataSource {
  final ApiClient _api;
  final int _grade;
  CurriculumRemoteDataSource(this._api, this._grade);

  @override
  Future<List<Chapter>> getChapters(String subjectId) async {
    final data = await _api.get('/subjects/$subjectId/chapters', queryParameters: {'grade': _grade});
    final list = (data['chapters'] as List? ?? []);
    return list.map((e) => Chapter(
          id: e['id'] as String,
          titleFa: e['title_fa'] as String,
          orderIndex: (e['order_index'] as num?)?.toInt() ?? 0,
          lessonCount: (e['lesson_count'] as num?)?.toInt() ?? 0,
          viewedCount: (e['viewed_count'] as num?)?.toInt() ?? 0,
          progressPercent: (e['progress_percent'] as num?)?.toDouble() ?? 0,
          completed: e['completed'] == true || e['completed'] == 1,
          unlocked: e['unlocked'] == true || e['unlocked'] == 1 || (e['order_index'] as num?)?.toInt() == 1,
          sourceBookId: e['source_book_id'] as String?,
        )).toList();
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
  Future<LessonViewResult> markLessonViewed(String lessonId) async {
    final data = await _api.post('/lessons/$lessonId/view');
    final m = Map<String, dynamic>.from(data as Map? ?? {});
    return LessonViewResult(
      pointsAwarded: (m['pointsAwarded'] as num?)?.toInt() ?? 0,
      chapterJustCompleted: m['chapterJustCompleted'] == true,
      chapterBonusAwarded: (m['chapterBonusAwarded'] as num?)?.toInt() ?? 0,
    );
  }
  Lesson _lessonFromJson(dynamic e) => Lesson(
        id: e['id'] as String, chapterId: e['chapter_id'] as String, titleFa: e['title_fa'] as String,
        estimatedMinutes: (e['estimated_minutes'] as num?)?.toInt() ?? 15,
        viewed: (e['viewed'] as num?)?.toInt() == 1 || e['viewed'] == true,
        contentBody: (e['content_body'] as String?) ?? '',
      );
}
