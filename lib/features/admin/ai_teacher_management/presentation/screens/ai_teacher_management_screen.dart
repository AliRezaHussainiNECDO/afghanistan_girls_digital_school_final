import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../../app/router/app_routes.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../ai_teacher/presentation/widgets/ai_engine_settings_card.dart';
import '../../../../curriculum_library/presentation/widgets/book_upload_section.dart';
import '../../domain/entities/ai_teacher_config.dart';
import '../../domain/usecases/ai_teacher_management_usecases.dart';
import '../providers/ai_teacher_management_providers.dart';
import '../widgets/ai_teacher_stats_section.dart';

class AiTeacherManagementScreen extends ConsumerWidget {
  const AiTeacherManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configsAsync = ref.watch(aiTeacherConfigsProvider);
    final scheme = Theme.of(context).colorScheme;

    return AppScaffold(
      title: context.tr('admin.aiTeacherManagement'),
      role: AppUserRole.superAdmin,
      body: configsAsync.when(
        loading: () => const LoadingView(),
        error: (e, st) => ErrorView(message: e.toString()),
        data: (configs) => ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: configs.length + 1,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AiTeacherStatsSection(),
                  const SizedBox(height: 16),
                  const AiEngineSettingsCard(),
                  const SizedBox(height: 10),
                  // ── ورود دسته‌ای کتاب‌های نصاب (صنف ۷ الی ۱۲ یک‌جا) ──
                  Material(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      onTap: () => context.push(AppRoutes.adminBulkImport),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.library_add_rounded,
                                color: scheme.onPrimaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ورود دسته‌ای کتاب‌های نصاب',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: scheme.onPrimaryContainer)),
                                  Text(
                                    'همهٔ PDF های دانلودشده (صنف ۷ الی ۱۲) را یک‌جا وارد کنید — تشخیص خودکار مضمون و صنف',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: scheme.onPrimaryContainer),
                                  ),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_left_rounded,
                                color: scheme.onPrimaryContainer),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
            final c = configs[i - 1];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPersonaCard(context, ref, scheme, c),
                BookUploadSection(subjectId: c.subjectId, subjectNameFa: c.subjectNameFa),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPersonaCard(
      BuildContext context, WidgetRef ref, ColorScheme scheme, AiTeacherConfig c) {
    return Material(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadii.lg),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadii.lg),
                onTap: () async {
                  final controller = TextEditingController(text: c.personaDescription);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(c.subjectNameFa),
                      content: TextField(controller: controller, maxLines: 3),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(context.tr('common.cancel')),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(context.tr('common.save')),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref
                        .read(updatePersonaUseCaseProvider)
                        .call(UpdatePersonaParams(subjectId: c.subjectId, newDescription: controller.text));
                    ref.invalidate(aiTeacherConfigsProvider);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(gradient: AppColors.sunriseGradient, shape: BoxShape.circle),
                        child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.subjectNameFa, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text(c.personaDescription,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: scheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                        ),
                        child: Text('v${c.promptVersion}',
                            style: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer)),
                      ),
                    ],
                  ),
                ),
              ),
            );
  }
}
