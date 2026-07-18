import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/curriculum_book.dart';

/// قرارداد مشترک DataSource کتابخانهٔ نصاب — Local (این فایل) و Remote (سرور)
/// هر دو آن را پیاده می‌کنند تا با سوییچ `kUseLiveBackend` تعویض شوند.
abstract class CurriculumLibraryDataSource {
  Future<List<CurriculumBook>> getBooksForSubject(String subjectId);
  Future<List<CurriculumBook>> getAllBooks();
  Future<CurriculumBook> addBook({
    required String subjectId,
    required String title,
    required int pageCount,
    required int gradeId,
    required String extractedText,
  });
  Future<void> deleteBook(String bookId);
}

/// ذخیرهٔ محلی کتاب‌های نصاب تعلیمی (JSON در SharedPreferences) — حالت
/// آفلاین/تست. برای جلوگیری از پر شدن ظرفیت ذخیرهٔ محلی، متن هر کتاب حداکثر
/// تا ۴۰۰ هزار نویسه نگه‌داری می‌شود (~۱۵۰ صفحهٔ متن فشرده).
class CurriculumLibraryLocalDataSource implements CurriculumLibraryDataSource {
  static const _storageKey = 'curriculum_books_v1';
  static const maxCharsPerBook = 400000;

  Future<List<CurriculumBook>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => CurriculumBook.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeAll(List<CurriculumBook> books) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(books.map((b) => b.toJson()).toList()));
  }

  @override
  Future<List<CurriculumBook>> getBooksForSubject(String subjectId) async {
    final all = await _readAll();
    return all.where((b) => b.subjectId == subjectId).toList()
      ..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
  }

  @override
  Future<List<CurriculumBook>> getAllBooks() async {
    final all = await _readAll();
    return all..sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
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
    final book = CurriculumBook(
      id: 'book_${DateTime.now().millisecondsSinceEpoch}',
      subjectId: subjectId,
      title: title,
      uploadedAt: DateTime.now(),
      pageCount: pageCount,
      gradeId: gradeId,
      extractedText: trimmed,
    );
    // اگر پیش‌تر کتابی برای همین مضمون+صنف آپلود شده، جایگزین می‌شود (هر
    // صنف فقط یک کتاب رسمی دارد).
    final all = await _readAll();
    all.removeWhere((b) => b.subjectId == subjectId && b.gradeId == gradeId && gradeId != 0);
    all.add(book);
    await _writeAll(all);
    return book;
  }

  @override
  Future<void> deleteBook(String bookId) async {
    final all = await _readAll();
    all.removeWhere((b) => b.id == bookId);
    await _writeAll(all);
  }
}
