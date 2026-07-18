import 'package:flutter/material.dart';
import '../../../../app/theme/design_tokens.dart';
import '../../../../core/localization/app_localizations.dart';

/// ابزارهای مشترک UI چت — آواتار گرادیانی، زمان نسبی و جداکنندهٔ تاریخ.
/// هم در صفحات شاگرد و هم در صفحات نظارتی مدیر استفاده می‌شوند تا زبان
/// طراحی چت در سراسر اپ یکسان بماند.

const List<Gradient> _avatarGradients = [
  AppColors.heroGradient,
  AppColors.successGradient,
  AppColors.heroGradientWarm,
  LinearGradient(colors: [AppColors.info, Color(0xFF2B65A0)]),
  LinearGradient(colors: [AppColors.gold500, AppColors.orange500]),
];

/// گرادیان پایدار بر اساس نام — هر شاگرد همیشه یک رنگ ثابت دارد.
Gradient avatarGradientFor(String name) =>
    _avatarGradients[name.codeUnits.fold<int>(0, (a, b) => a + b) % _avatarGradients.length];

class ChatAvatar extends StatelessWidget {
  final String name;
  final bool isAdmin;
  final double size;

  /// عکس پروفایل واقعی کاربر (سرور R2)؛ اگر null باشد حرف اول با گرادیان.
  final String? avatarUrl;

  const ChatAvatar({
    super.key,
    required this.name,
    this.isAdmin = false,
    this.size = 44,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    // اگر عکس پروفایل موجود است، همان نمایش داده می‌شود (در صورت خطای
    // بارگیری شبکه، خودکار به حرف اول برمی‌گردد).
    if (!isAdmin && avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: AppShadows.soft),
        child: CircleAvatar(
          radius: size / 2,
          backgroundColor: Colors.transparent,
          foregroundImage: NetworkImage(avatarUrl!),
          onForegroundImageError: (_, __) {},
          child: _fallback(),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: isAdmin ? AppColors.successGradient : avatarGradientFor(name),
        shape: BoxShape.circle,
        boxShadow: AppShadows.soft,
      ),
      child: Center(
        child: isAdmin
            ? Icon(Icons.shield_rounded, color: Colors.white, size: size * 0.46)
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Text(
        name.isEmpty ? '?' : name.characters.first,
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.4),
      );
}

/// زمان نسبی — طبق زبان فعال («همین حالا»، «۵ دقیقه پیش»، «دیروز»، یا تاریخ).
String relativeTimeFa(BuildContext context, DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return context.tr('notifications.justNow');
  if (diff.inMinutes < 60) return context.tr('notifications.minutesAgo', {'count': '${diff.inMinutes}'});
  if (diff.inHours < 24 && time.day == DateTime.now().day) {
    return context.tr('notifications.hoursAgo', {'count': '${diff.inHours}'});
  }
  if (diff.inHours < 48) return context.tr('notifications.bucketYesterday');
  return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
}

/// برچسب جداکنندهٔ تاریخ بین پیام‌ها — «امروز»، «دیروز» یا تاریخ کامل.
String dateLabelFa(BuildContext context, DateTime time) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(time.year, time.month, time.day);
  if (day == today) return context.tr('notifications.bucketToday');
  if (day == today.subtract(const Duration(days: 1))) return context.tr('notifications.bucketYesterday');
  return '${time.year}/${time.month.toString().padLeft(2, '0')}/${time.day.toString().padLeft(2, '0')}';
}

/// ساعت پیام به فرمت HH:MM.
String clockFa(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

class DateSeparator extends StatelessWidget {
  final DateTime date;
  const DateSeparator({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: scheme.outlineVariant)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(dateLabelFa(context, date),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),
          Expanded(child: Divider(color: scheme.outlineVariant)),
        ],
      ),
    );
  }
}
