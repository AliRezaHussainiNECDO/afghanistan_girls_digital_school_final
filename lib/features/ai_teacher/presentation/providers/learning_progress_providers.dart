import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/learning_progress_datasource.dart';
import '../../domain/entities/learning_progress.dart';
import 'ai_teacher_providers.dart';

final learningProgressDataSourceProvider = Provider(
    (ref) => LearningProgressDataSource(ref.watch(curriculumLibraryForAiProvider)));

/// صنف فعلی شاگرد (۷ الی ۱۲) — پایهٔ تدریس مطابق نصاب همان صنف.
class StudentGradeNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() =>
      ref.read(learningProgressDataSourceProvider).getStudentGrade();

  Future<void> setGrade(int grade) async {
    await ref.read(learningProgressDataSourceProvider).setStudentGrade(grade);
    state = AsyncData(grade);
    ref.invalidate(learningProgressProvider);
  }
}

final studentGradeProvider =
    AsyncNotifierProvider<StudentGradeNotifier, int>(StudentGradeNotifier.new);

/// پیشرفت یادگیری همهٔ مضامین — برای داشبورد، معلم هوشمند و تقسیم اوقات.
final learningProgressProvider =
    FutureProvider<List<SubjectLearningProgress>>((ref) async {
  // با تغییر صنف، خودکار دوباره محاسبه شود.
  await ref.watch(studentGradeProvider.future);
  return ref.read(learningProgressDataSourceProvider).getAll();
});

/// مضمونی که کاربر از داشبورد/تقسیم اوقات انتخاب کرده تا معلم هوشمند
/// مستقیماً با همان مضمون باز شود (Deep-link داخلی).
final aiTeacherInitialSubjectProvider = StateProvider<String?>((ref) => null);
