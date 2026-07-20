import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../../../core/widgets/app_scaffold.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../../core/widgets/loading_view.dart';
import '../../../../auth/domain/entities/app_user.dart';
import '../../../../ai_teacher/presentation/widgets/ai_engine_settings_card.dart';
import '../../domain/entities/ai_teacher_config.dart';
import '../../domain/usecases/ai_teacher_management_usecases.dart';
import '../providers/ai_teacher_management_providers.dart';
import '../widgets/ai_curriculum_generate_panel.dart';
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
        error: (e, st) => ErrorView(error: e),
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
                  // ═══ تولید هوشمند نصاب (Pure AI Generation — Gemini) ═══
                  // جایگزین کامل سیستم قدیمی مبتنی بر PDF: تمام گزینه‌های
                  // فایل‌محور (ورود دسته‌ای PDF، رفع متن‌های معکوس، پاک‌سازی
                  // دروس یتیم، آپلود کتاب هر مضمون) از این رابط حذف شدند —
                  // منبع مطلق محتوا خودِ Gemini است.
                  const AiCurriculumGeneratePanel(),
                  const SizedBox(height: 10),
                  // ── نظارت/بازنویسی رفتار پایه و پرامپت معلم هوشمند ──
                  const AiBasePromptCard(),
                ],
              );
            }
            final c = configs[i - 1];
            return _buildPersonaCard(context, ref, scheme, c);
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
