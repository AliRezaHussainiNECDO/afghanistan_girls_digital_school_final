import '../../../../core/network/api_client.dart';
import '../../domain/entities/curriculum_book.dart';
import 'curriculum_library_local_datasource.dart' show CurriculumLibraryDataSource;

/// پیاده‌سازی واقعی کتابخانهٔ نصاب روی سرور (روتر `/api/v1/curriculum-library/*`).
/// متن استخراج‌شدهٔ کتاب‌ها روی D1 ذخیره می‌شود تا پایگاه دانش معلم هوشمند
/// بین همهٔ کاربران مشترک و ماندگار باشد.
class CurriculumLibraryRemoteDataSource implements CurriculumLibraryDataSource {
  final ApiClient _api;
  CurriculumLibraryRemoteDataSource(this._api);

  static const maxCharsPerBook = 400000;

  Map<String, dynamic> _map(dynamic d) =>
      d is Map<String, dynamic> ? d : Map<String, dynamic>.from(d as Map);

  @override
  Future<List<CurriculumBook>> getBooksForSubject(String subjectId) async {
    final data = _map(await _api.get('/curriculum-library/subjects/$subjectId/books'));
    final list = (data['books'] as List? ?? []);
    return list.map((e) => CurriculumBook.fromJson(_map(e))).toList();
  }

  @override
  Future<List<CurriculumBook>> getAllBooks() async {
    final data = _map(await _api.get('/curriculum-library/books'));
    final list = (data['books'] as List? ?? []);
    return list.map((e) => CurriculumBook.fromJson(_map(e))).toList();
  }

  @override
  Future<CurriculumBook> addBook({
    required String subjectId,
    required String title,
    required int pageCount,
    required int gradeId,
    required String extractedText,
  }) async {
    final trimmed = extractedText.length > maxCharsPerBook
        ? extractedText.substring(0, maxCharsPerBook)
        : extractedText;
    final data = _map(await _api.post('/curriculum-library/books', data: {
      'subjectId': subjectId,
      'title': title,
      'pageCount': pageCount,
      'gradeId': gradeId,
      'extractedText': trimmed,
    }));
    return CurriculumBook.fromJson(_map(data['book']));
  }

  @override
  Future<void> deleteBook(String bookId) async {
    await _api.delete('/curriculum-library/books/$bookId');
  }
}
