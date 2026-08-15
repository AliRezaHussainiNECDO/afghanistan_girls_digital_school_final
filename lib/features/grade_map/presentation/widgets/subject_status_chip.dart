import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/grade_map.dart';

class SubjectStatusChip extends StatelessWidget {
  final SubjectProgressStatus status;
  const SubjectStatusChip({super.key, required this.status});

  // رفع اشکال هماهنگی طراحی: قبلاً رنگ‌های خام Material (grey/blue/purple/...)
  // استفاده می‌شد که نه با پالت گرم/محدودِ design_tokens.dart هماهنگ بود و نه
  // در حالت تاریک قابل تنظیم. چون این پالت عمداً محدود است (نارنجی/سبز/طلایی
  // + یک لهجهٔ info، بدون آبی/بنفشِ کلاسیک — نگاه کنید به توضیح بالای
  // design_tokens.dart)، به‌جای افزودن رنگ‌های تازه، هر ۷ وضعیت به نزدیک‌ترین
  // توکنِ موجود نگاشت شدند تا هم یکتا/قابل‌تشخیص بمانند و هم زبانِ طراحی اپ
  // را نشکنند: locked=خنثی، unlocked=info (تنها لهجهٔ آبی رسمی)،
  // inProgress=نارنجیِ برند، completed=سبز، failed=danger،
  // retryWindow=طلایی («فرصت دوباره»)، remedialRequired=نارنجیِ تیره‌تر
  // (خانوادهٔ نارنجی ولی به‌وضوح از inProgress متمایز).
  ({Color color, IconData icon, String key}) get _config {
    switch (status) {
      case SubjectProgressStatus.locked:
        return (color: AppColors.ink500, icon: Icons.lock_outline, key: 'gradeMap.locked');
      case SubjectProgressStatus.unlocked:
        return (color: AppColors.info, icon: Icons.lock_open_outlined, key: 'gradeMap.unlocked');
      case SubjectProgressStatus.inProgress:
        return (color: AppColors.orange500, icon: Icons.hourglass_top, key: 'gradeMap.inProgress');
      case SubjectProgressStatus.completed:
        return (color: AppColors.green600, icon: Icons.check_circle_outline, key: 'gradeMap.completed');
      case SubjectProgressStatus.failed:
        return (color: AppColors.danger, icon: Icons.cancel_outlined, key: 'gradeMap.failed');
      case SubjectProgressStatus.retryWindow:
        return (color: AppColors.gold600, icon: Icons.replay, key: 'gradeMap.retryWindow');
      case SubjectProgressStatus.remedialRequired:
        return (
          color: AppColors.orange700,
          icon: Icons.support_outlined,
          key: 'gradeMap.remedialRequired'
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    return Chip(
      avatar: Icon(config.icon, size: 16, color: config.color),
      label: Text(context.tr(config.key)),
      labelStyle: TextStyle(color: config.color, fontSize: 12),
      backgroundColor: config.color.withValues(alpha: 0.1),
      side: BorderSide(color: config.color.withValues(alpha: 0.3)),
    );
  }
}
