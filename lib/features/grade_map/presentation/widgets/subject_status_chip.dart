import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/grade_map.dart';

class SubjectStatusChip extends StatelessWidget {
  final SubjectProgressStatus status;
  const SubjectStatusChip({super.key, required this.status});

  ({Color color, IconData icon, String key}) get _config {
    switch (status) {
      case SubjectProgressStatus.locked:
        return (color: Colors.grey, icon: Icons.lock_outline, key: 'gradeMap.locked');
      case SubjectProgressStatus.unlocked:
        return (color: Colors.blue, icon: Icons.lock_open_outlined, key: 'gradeMap.unlocked');
      case SubjectProgressStatus.inProgress:
        return (color: Colors.orange, icon: Icons.hourglass_top, key: 'gradeMap.inProgress');
      case SubjectProgressStatus.completed:
        return (color: Colors.green, icon: Icons.check_circle_outline, key: 'gradeMap.completed');
      case SubjectProgressStatus.failed:
        return (color: Colors.red, icon: Icons.cancel_outlined, key: 'gradeMap.failed');
      case SubjectProgressStatus.retryWindow:
        return (color: Colors.deepOrange, icon: Icons.replay, key: 'gradeMap.retryWindow');
      case SubjectProgressStatus.remedialRequired:
        return (
          color: Colors.purple,
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
