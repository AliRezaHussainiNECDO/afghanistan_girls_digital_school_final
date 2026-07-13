import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/student/selected_grade_provider.dart';
import '../../data/datasources/learning_progress_datasource.dart';
import '../../domain/entities/learning_progress.dart';
import 'ai_teacher_providers.dart';

final learningProgressDataSourceProvider = Provider(
    (ref) => LearningProgressDataSource(ref.watch(curriculumLibraryForAiProvider)));

/// پیشرفت یادگیری همهٔ مضامین **صنف فعال واقعی شاگرد** — برای داشبورد،
/// معلم هوشمند و تقسیم اوقات. منبع صنف: `activeGradeProvider` (همان صنفی
/// که در نقشهٔ صنوف/داشبورد استفاده می‌شود؛ اینجا دیگر صنف جداگانه‌ای
/// ذخیره/انتخاب نمی‌شود تا هرگز با صنف واقعی شاگرد ناهماهنگ نشود).
final learningProgressProvider =
    FutureProvider<List<SubjectLearningProgress>>((ref) async {
  final grade = ref.watch(activeGradeProvider);
  return ref.read(learningProgressDataSourceProvider).getAll(grade);
});

/// مضمونی که کاربر از داشبورد/تقسیم اوقات انتخاب کرده تا معلم هوشمند
/// مستقیماً با همان مضمون باز شود (Deep-link داخلی).
final aiTeacherInitialSubjectProvider = StateProvider<String?>((ref) => null);
