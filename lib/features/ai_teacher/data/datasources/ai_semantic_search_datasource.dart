import '../../../../core/network/api_client.dart';
import '../../../curriculum_library/domain/entities/curriculum_book.dart';

/// بازیابی معنایی (RAG واقعی) از سرور — به‌جای تطابق سادهٔ کلمه‌ای محلی
/// ([BookSectionUtils.findRelevant])، پرسش شاگرد را Embed می‌کند و با
/// شباهت کسینوسی نزدیک‌ترین درس‌های همان مضمون/صنف را برمی‌گرداند، مستقل
/// از عین کلمات، بر اساس معنا.
///
/// کاملاً Fail-safe: هر خطا (بدون اینترنت، کلید تنظیم‌نشده، هنوز نمایه
/// نشده) فقط لیست خالی برمی‌گرداند تا لایهٔ بالاتر بی‌صدا به روش قبلی
/// (بازیابی کلمه‌ای محلی) برگردد — گفتگو هرگز به‌خاطر این قابلیت خراب
/// نمی‌شود.
class AiSemanticSearchDataSource {
  final ApiClient _api;
  AiSemanticSearchDataSource(this._api);

  Future<List<BookSection>> search({
    required String subjectId,
    required int grade,
    required String query,
    int topN = 3,
  }) async {
    try {
      final data = await _api.post('/ai-teacher/semantic-search', data: {
        'subjectId': subjectId,
        'gradeId': grade,
        'query': query,
        'topN': topN,
      });
      final results = (data is Map ? data['results'] as List? : null) ?? const [];
      return [
        for (var i = 0; i < results.length; i++)
          _fromJson(Map<String, dynamic>.from(results[i] as Map), i),
      ];
    } catch (_) {
      return const [];
    }
  }

  BookSection _fromJson(Map<String, dynamic> j, int index) => BookSection(
        bookId: j['lessonId'] as String? ?? 'semantic-$index',
        bookTitle: j['bookTitle'] as String? ?? '',
        index: index,
        heading: j['heading'] as String? ?? '',
        content: j['content'] as String? ?? '',
      );
}
