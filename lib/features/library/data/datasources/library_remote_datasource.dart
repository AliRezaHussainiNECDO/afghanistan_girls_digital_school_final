import '../../../../core/network/api_client.dart';
import '../../domain/entities/book.dart';

/// قرارداد مشترک DataSource کتابخانه — Mock و Remote هر دو آن را پیاده
/// می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class LibraryDataSource {
  Future<List<Book>> search(String query);
}

/// پیاده‌سازی واقعی — `GET /api/v1/books` (بخش ۱۱). متادیتای کتاب‌ها از D1 و
/// فایل PDF از R2 خوانده می‌شود؛ جستجو روی عنوان در کلاینت اعمال می‌شود.
class LibraryRemoteDataSource implements LibraryDataSource {
  final ApiClient _api;
  LibraryRemoteDataSource(this._api);

  @override
  Future<List<Book>> search(String query) async {
    final data = await _api.get('/books');
    final list = (data as List? ?? []);
    final books = list.map((b) {
      final m = Map<String, dynamic>.from(b as Map);
      return Book(
        id: m['id'] as String,
        titleFa: m['title'] as String? ?? '',
        category: 'کتاب درسی رسمی',
        language: 'دری',
        fileSizeMb: 0,
        includeInRag: false,
      );
    }).toList();
    final q = query.trim();
    if (q.isEmpty) return books;
    return books.where((b) => b.titleFa.contains(q)).toList();
  }
}
