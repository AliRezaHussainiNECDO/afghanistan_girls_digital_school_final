import 'package:equatable/equatable.dart';

/// طبق بخش ۱۷.۲ سند: `chapters` سطح بالا، `units` زیرتقسیم اختیاری،
/// `lessons` می‌تواند مستقیم زیر Chapter یا زیر Unit باشد.
class Chapter extends Equatable {
  final String id;
  final String titleFa;
  final int orderIndex;
  final int lessonCount;

  const Chapter({
    required this.id,
    required this.titleFa,
    required this.orderIndex,
    required this.lessonCount,
  });

  @override
  List<Object?> get props => [id];
}

class Lesson extends Equatable {
  final String id;
  final String chapterId;
  final String titleFa;
  final int estimatedMinutes;
  final bool viewed; // طبق C1 بخش ۶.۲ — Backend صاحب حقیقت است
  final String contentBody;

  const Lesson({
    required this.id,
    required this.chapterId,
    required this.titleFa,
    required this.estimatedMinutes,
    required this.viewed,
    required this.contentBody,
  });

  @override
  List<Object?> get props => [id, viewed];
}
