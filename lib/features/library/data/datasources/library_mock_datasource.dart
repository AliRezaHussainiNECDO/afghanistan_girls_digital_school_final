import '../../domain/entities/book.dart';
import 'library_remote_datasource.dart' show LibraryDataSource;

class LibraryMockDataSource implements LibraryDataSource {
  static const _allBooks = [
    Book(id: 'b1', titleFa: 'ریاضی صنف نهم', category: 'کتاب درسی رسمی', language: 'دری', fileSizeMb: 12.4, includeInRag: true),
    Book(id: 'b2', titleFa: 'داستان‌های کوتاه دری', category: 'داستان', language: 'دری', fileSizeMb: 3.1),
    Book(id: 'b3', titleFa: 'فزیک صنف نهم', category: 'کتاب درسی رسمی', language: 'دری', fileSizeMb: 15.7, includeInRag: true),
    Book(id: 'b4', titleFa: 'مهارت‌های زندگی برای نوجوانان', category: 'مهارت زندگی', language: 'دری', fileSizeMb: 4.2),
    Book(id: 'b5', titleFa: 'English Grammar Basics', category: 'کمک‌درسی', language: 'انگلیسی', fileSizeMb: 6.0),
  ];

  @override
  Future<List<Book>> search(String query) async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (query.trim().isEmpty) return _allBooks;
    return _allBooks.where((b) => b.titleFa.contains(query)).toList();
  }
}
