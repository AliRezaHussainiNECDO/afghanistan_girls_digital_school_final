import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/exam_entities.dart';

abstract class ExamsRepository {
  Future<Either<Failure, List<ExamSummary>>> getAvailableExams();
  Future<Either<Failure, List<ExamQuestion>>> getQuestions(String examId);

  /// طبق بخش ۷.۲ سند: `Score = (تعداد پاسخ صحیح / تعداد کل) × ۱۰۰`،
  /// محاسبه در Backend انجام می‌شود — Client فقط پاسخ‌ها را می‌فرستد.
  /// [textAnswers]: پاسخ متنی سؤالات تشریحی (نمره‌دهی AI سمت سرور).
  Future<Either<Failure, ExamResult>> submitAnswers(
      String examId, Map<String, int> answers, Map<String, String> textAnswers);

  /// نتایج امتحانات رسمی — خودِ کاربر (بدون [studentId]) یا فرزندِ والد
  /// (با [studentId]، هماهنگ با داشبورد شاگرد).
  Future<Either<Failure, List<ExamResultSummary>>> getMyResults({String? studentId});

  /// مرور سؤال‌به‌سؤالِ یک تلاش — پاسخ داده‌شده و درست/غلط.
  Future<Either<Failure, ExamAttemptReview>> getAttemptReview(String attemptId);
}
