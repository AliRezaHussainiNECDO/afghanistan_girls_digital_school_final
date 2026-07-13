import '../../domain/entities/curriculum_entities.dart';
import 'curriculum_remote_datasource.dart' show CurriculumDataSource;

/// طبق بخش ۵.۳.۱: هر Lesson معمولاً هم‌اندازهٔ یک بخش از کتاب رسمی است.
class CurriculumMockDataSource implements CurriculumDataSource {
  final Map<String, bool> _viewedLessons = {};

  @override
  Future<List<Chapter>> getChapters(String subjectId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.generate(
      6,
      (i) => Chapter(
        id: '$subjectId-ch${i + 1}',
        titleFa: 'فصل ${i + 1}',
        orderIndex: i + 1,
        lessonCount: 4,
      ),
    );
  }

  @override
  Future<List<Lesson>> getLessons(String chapterId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.generate(4, (i) {
      final id = '$chapterId-l${i + 1}';
      return Lesson(
        id: id,
        chapterId: chapterId,
        titleFa: 'درس ${i + 1}',
        estimatedMinutes: 15 + (i * 5),
        viewed: _viewedLessons[id] ?? (i == 0),
        contentBody:
            'این متن جای‌گیر محتوای ساختاریافتهٔ درس است (طبق بخش ۱۷.۲: content_body JSON). '
            'در فاز ۴ این محتوا از طریق CMS (بخش ۱۴.۳) وارد و برای RAG (بخش ۵.۳) Embed می‌شود.',
      );
    });
  }

  @override
  Future<Lesson> getLesson(String lessonId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final chapterId = lessonId.substring(0, lessonId.lastIndexOf('-l'));
    return Lesson(
      id: lessonId,
      chapterId: chapterId,
      titleFa: 'درس ${lessonId.split('-l').last}',
      estimatedMinutes: 20,
      viewed: _viewedLessons[lessonId] ?? false,
      contentBody:
          'این متن جای‌گیر محتوای ساختاریافتهٔ درس است (طبق بخش ۱۷.۲: content_body JSON).',
    );
  }

  @override
  Future<void> markLessonViewed(String lessonId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    _viewedLessons[lessonId] = true;
  }
}
