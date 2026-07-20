import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../../app/theme/design_tokens.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../domain/entities/homework.dart';

/// کارت شیشه‌ای (Glassmorphism) یک مشق در فهرست داشبورد — ظاهر بر اساس
/// وضعیت تغییر می‌کند: در انتظار (دکمهٔ دوربین)، ارسال‌شده (در حال نمره‌دهی)،
/// نمره‌گرفته (نمره + بازخورد کوتاه، قابل لمس برای گفتگو با معلم هوشمند).
class HomeworkCard extends StatelessWidget {
  final Homework homework;
  final bool uploading;
  final VoidCallback onCapture;
  final VoidCallback onOpenChat;

  const HomeworkCard({
    super.key,
    required this.homework,
    required this.onCapture,
    required this.onOpenChat,
    this.uploading = false,
  });

  @override
  Widget build(BuildContext context) {
    final hw = homework;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: InkWell(
          onTap: hw.canDiscussGrade ? onOpenChat : null,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppRadii.lg),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: _iconGradient,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                      ),
                      child: Icon(_iconForStatus, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(hw.subjectNameFa,
                              style: const TextStyle(color: Colors.white70, fontSize: 11.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          // (رفع اشکال) صورت سؤال هرگز بریده نمی‌شود — شاگرد
                          // باید متن کامل را بخواند تا بتواند پاسخ بنویسد؛
                          // کارت به اندازهٔ طول متن کش می‌آید.
                          Text(
                            hw.questionText,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(status: hw.status),
                  ],
                ),
                if (hw.hintText.trim().isNotEmpty && hw.status == HomeworkStatus.pending) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 15, color: AppColors.gold500),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(hw.hintText,
                            style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.5)),
                      ),
                    ],
                  ),
                ],
                // ── عکس ارسالی شاگرد — (رفع اشکال) قبلاً فقط مدیر عکس را
                // می‌دید؛ حالا خود شاگرد هم بعد از ارسال، عکسش را همین‌جا
                // می‌بیند تا مطمئن شود درست آپلود شده است.
                if (hw.hasImage && !hw.studentImageUrl.startsWith('mock://')) ...[
                  const SizedBox(height: 12),
                  Text(context.tr('homework.yourSubmission'),
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: Image.network(
                      hw.studentImageUrl,
                      width: double.infinity,
                      height: 170,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) => progress == null
                          ? child
                          : Container(
                              height: 170,
                              alignment: Alignment.center,
                              color: Colors.white.withValues(alpha: 0.06),
                              child: const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2)),
                            ),
                      errorBuilder: (_, __, ___) => Container(
                        height: 56,
                        alignment: Alignment.center,
                        color: Colors.white.withValues(alpha: 0.06),
                        child: Text(context.tr('homework.imageUnavailable'),
                            style: const TextStyle(color: Colors.white38, fontSize: 11.5)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                if (hw.status == HomeworkStatus.pending) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orange500,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                      ),
                      onPressed: uploading ? null : onCapture,
                      icon: uploading
                          ? const SizedBox(
                              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.camera_alt_rounded, size: 18),
                      label: Text(
                        uploading ? context.tr('homework.uploading') : context.tr('homework.capturePhoto'),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ] else if (hw.status == HomeworkStatus.submitted) ...[
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.gold500),
                      ),
                      const SizedBox(width: 8),
                      Text(context.tr('homework.gradingInProgress'),
                          style: const TextStyle(color: Colors.white60, fontSize: 12.5)),
                    ],
                  ),
                ] else if (hw.isGraded) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _scoreColor(hw.aiScore!).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.grade_rounded, size: 16, color: _scoreColor(hw.aiScore!)),
                        const SizedBox(width: 6),
                        Text('${hw.aiScore}/100',
                            style: TextStyle(color: _scoreColor(hw.aiScore!), fontWeight: FontWeight.w800, fontSize: 13)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hw.aiFeedback,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 12, height: 1.5),
                          ),
                        ),
                        const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white38),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  LinearGradient get _iconGradient => switch (homework.status) {
        HomeworkStatus.pending => AppColors.heroGradientWarm,
        HomeworkStatus.submitted => AppColors.sunriseGradient,
        HomeworkStatus.graded => AppColors.successGradient,
      };

  IconData get _iconForStatus => switch (homework.status) {
        HomeworkStatus.pending => Icons.edit_note_rounded,
        HomeworkStatus.submitted => Icons.hourglass_top_rounded,
        HomeworkStatus.graded => Icons.workspace_premium_rounded,
      };

  Color _scoreColor(int score) {
    if (score >= 80) return AppColors.green300;
    if (score >= 50) return AppColors.gold500;
    return AppColors.danger;
  }
}

class _StatusPill extends StatelessWidget {
  final HomeworkStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      HomeworkStatus.pending => (context.tr('homework.statusPending'), AppColors.orange400),
      HomeworkStatus.submitted => (context.tr('homework.statusSubmitted'), AppColors.gold500),
      HomeworkStatus.graded => (context.tr('homework.statusGraded'), AppColors.green300),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800)),
    );
  }
}
