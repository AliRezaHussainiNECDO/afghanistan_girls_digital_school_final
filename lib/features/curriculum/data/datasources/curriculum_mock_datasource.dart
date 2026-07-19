import '../../domain/entities/curriculum_entities.dart';
import 'curriculum_remote_datasource.dart' show CurriculumDataSource;

class CurriculumMockDataSource implements CurriculumDataSource {
  final Map<String, bool> _viewedLessons = {};

  /// درس‌هایی که شاگرد «یاد گرفتم» زده — برای هر درس فقط یک کار خانگی (Mock).
  final Set<String> _learnedLessons = {};
  static const int _lessonsPerChapter = 4;

  bool _isChapterCompleted(String chapterId) {
    for (var i = 1; i <= _lessonsPerChapter; i++) {
      if (_viewedLessons['$chapterId-l$i'] != true) return false;
    }
    return true;
  }

  int _viewedCountFor(String chapterId) {
    var n = 0;
    for (var i = 1; i <= _lessonsPerChapter; i++) {
      if (_viewedLessons['$chapterId-l$i'] == true) n++;
    }
    return n;
  }

  @override
  Future<List<Chapter>> getChapters(String subjectId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    var previousCompleted = true;
    return List.generate(6, (i) {
      final chapterId = '$subjectId-ch${i + 1}';
      final completed = _isChapterCompleted(chapterId);
      final viewedCount = _viewedCountFor(chapterId);
      final unlocked = previousCompleted;
      previousCompleted = completed;
      return Chapter(
        id: chapterId,
        titleFa: 'فصل ${i + 1}',
        orderIndex: i + 1,
        lessonCount: _lessonsPerChapter,
        viewedCount: viewedCount,
        progressPercent: (viewedCount / _lessonsPerChapter) * 100,
        completed: completed,
        unlocked: unlocked,
      );
    });
  }

  @override
  Future<List<Lesson>> getLessons(String chapterId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return List.generate(_lessonsPerChapter, (i) {
      final id = '$chapterId-l${i + 1}';
      return Lesson(
        id: id,
        chapterId: chapterId,
        titleFa: 'درس ${i + 1}',
        estimatedMinutes: 15 + (i * 5),
        viewed: _viewedLessons[id] ?? false,
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
  Future<LessonViewResult> markLessonViewed(String lessonId) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final firstView = _viewedLessons[lessonId] != true;
    _viewedLessons[lessonId] = true;
    if (!firstView) {
      return const LessonViewResult(pointsAwarded: 0, chapterJustCompleted: false, chapterBonusAwarded: 0);
    }
    final chapterId = lessonId.substring(0, lessonId.lastIndexOf('-l'));
    final justCompleted = _isChapterCompleted(chapterId);
    return LessonViewResult(
      pointsAwarded: 10,
      chapterJustCompleted: justCompleted,
      chapterBonusAwarded: justCompleted ? 25 : 0,
    );
  }

  @override
  Future<LessonLearnedResult> markLessonLearned(String lessonId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _viewedLessons[lessonId] = true;
    final first = _learnedLessons.add(lessonId);
    return LessonLearnedResult(assigned: first, alreadyAssigned: !first);
  }
}
