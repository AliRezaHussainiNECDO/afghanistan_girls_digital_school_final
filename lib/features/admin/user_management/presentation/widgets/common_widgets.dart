/// کامپوننت‌های مشترک بخش مدیریت شاگردان — طراحی مدرن Material 3.
import 'package:flutter/material.dart';

import '../../domain/entities/student_entities.dart';

class AppPalette {
  static const green = Color(0xFF16A085);
  static const greenDark = Color(0xFF0E6655);
  static const red = Color(0xFFE74C3C);
  static const amber = Color(0xFFF39C12);
  static const ink = Color(0xFF1C2833);
  static const surface = Color(0xFFF4F6F8);
}

class StatusBadge extends StatelessWidget {
  final AccountStatus status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AccountStatus.active => ('فعال', AppPalette.green),
      AccountStatus.suspended => ('مسدود', AppPalette.red),
      AccountStatus.pendingVerification => ('در انتظار تأیید', AppPalette.amber),
      AccountStatus.deleted => ('حذف‌شده', Colors.grey),
    };
    return _Pill(label: label, color: color);
  }
}

class RiskBadge extends StatelessWidget {
  final RiskLevel level;
  const RiskBadge(this.level, {super.key});

  @override
  Widget build(BuildContext context) {
    if (level == RiskLevel.none) return const SizedBox.shrink();
    final (label, color) = switch (level) {
      RiskLevel.high => ('در معرض خطر', AppPalette.red),
      RiskLevel.medium => ('نیاز به توجه', AppPalette.amber),
      _ => ('پیگیری', Colors.blueGrey),
    };
    return _Pill(label: label, color: color, icon: Icons.warning_amber_rounded);
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  const _Pill({required this.label, required this.color, this.icon});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      );
}

/// نوار پیشرفت با رنگ معنادار — مقدار از سرور می‌آید، کلاینت فقط رنگ نمایش را
/// انتخاب می‌کند (تصمیم آموزشی نیست).
class ScoreBar extends StatelessWidget {
  final double value; // 0..100
  final String? label;
  const ScoreBar({super.key, required this.value, this.label});

  @override
  Widget build(BuildContext context) {
    final color = value >= 75
        ? AppPalette.green
        : (value >= 50 ? AppPalette.amber : AppPalette.red);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label!, style: Theme.of(context).textTheme.bodySmall),
              Text('٪${value.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: color, fontSize: 12)),
            ],
          ),
        ),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: value / 100,
          minHeight: 8,
          backgroundColor: color.withOpacity(.12),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppPalette.green,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
                radius: 16,
                backgroundColor: color.withOpacity(.12),
                child: Icon(icon, size: 18, color: color)),
            const SizedBox(height: 10),
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          ],
        ),
      );
}

/// نقشهٔ حرارتی حاضری ۳۰ روز اخیر.
class AttendanceHeatmap extends StatelessWidget {
  final List<AttendanceDay> days;
  const AttendanceHeatmap({super.key, required this.days});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 5,
        runSpacing: 5,
        children: days
            .map((d) => Tooltip(
                  message:
                      '${d.date.year}/${d.date.month}/${d.date.day} — ${d.present ? 'حاضر' : 'غایب'}',
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: d.present
                          ? AppPalette.green
                          : AppPalette.red.withOpacity(.75),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ))
            .toList(),
      );
}

/// سنجهٔ سطح استرس در گزارش استاد AI.
class StressGauge extends StatelessWidget {
  final StressLevel level;
  const StressGauge({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    final (label, color, fill) = switch (level) {
      StressLevel.low => ('کم', AppPalette.green, .25),
      StressLevel.medium => ('متوسط', AppPalette.amber, .6),
      StressLevel.high => ('بالا', AppPalette.red, .95),
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('سطح استرس',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ]),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: LinearProgressIndicator(
          value: fill,
          minHeight: 10,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    ]);
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;
  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.05),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 20, color: AppPalette.greenDark),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold))),
            if (trailing != null) trailing!,
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}
