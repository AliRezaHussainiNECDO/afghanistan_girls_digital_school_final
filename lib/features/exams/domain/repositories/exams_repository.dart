import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../entities/exam_entities.dart';

abstract class ExamsRepository {
  Future<Either<Failure, List<ExamSummary>>> getAvailableExams();
  Future<Either<Failure, List<ExamQuestion>>> getQuestions(String examId);

  /// طبق بخش ۷.۲ سند: `Score = (تعداد پاسخ صحیح / تعداد کل) × ۱۰۰`،
  /// محاسبه در Backend انجام می‌شود — Client فقط پاسخ‌ها را می‌فرستد.
  Future<Either<Failure, ExamResult>> submitAnswers(String examId, Map<String, int> answers);
}
