import 'package:equatable/equatable.dart';

/// طبق بخش ۱۱ و ۱۷.۲ سند (`books`).
class Book extends Equatable {
  final String id;
  final String titleFa;
  final String category; // کتاب درسی رسمی/کمک‌درسی/داستان/مهارت زندگی
  final String language;
  final double fileSizeMb;
  final bool includeInRag; // بخش ۱۱.۱ — تصمیم Ingestion به RAG

  const Book({
    required this.id,
    required this.titleFa,
    required this.category,
    required this.language,
    required this.fileSizeMb,
    this.includeInRag = false,
  });

  @override
  List<Object?> get props => [id];
}
