import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/student/grade_widgets.dart';
import '../../../../core/student/selected_grade_provider.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../auth/domain/entities/app_user.dart';

/// مضامین صنف انتخاب‌شده — با نوار انتخاب صنف در بالا. با تغییر صنف،
/// مضامین همان صنف نمایش داده می‌شود (طبق درخواست کاربر).
class CurriculumScreen extends ConsumerWidget {
  const CurriculumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grade = ref.watch(selectedGradeProvider);
    final scheme = Theme.of(context).colorScheme;
    return AppScaffold(
      title: context.tr('nav.curriculum'),
      role: AppUserRole.student,
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GradeSelector(),
            const SizedBox(height: 18),
            Text(context.tr('dashboard.subjectsOfGrade', {'grade': '$grade'}),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: scheme.onSurface)),
            const SizedBox(height: 12),
            const Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 16),
                child: GradeSubjectsGrid(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
