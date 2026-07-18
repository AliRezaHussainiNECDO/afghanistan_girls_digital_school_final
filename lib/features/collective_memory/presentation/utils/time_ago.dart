import 'package:flutter/widgets.dart';
import '../../../../core/localization/app_localizations.dart';

/// نمایش زمان نسبی — طبق زبان فعال برنامه (چهار زبان)، بدون نیاز به پکیج
/// اضافه، فقط برای این بخش.
String timeAgoFa(BuildContext context, DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return context.tr('memory.justNow');
  if (diff.inMinutes < 60) return context.tr('notifications.minutesAgo', {'count': '${diff.inMinutes}'});
  if (diff.inHours < 24) return context.tr('notifications.hoursAgo', {'count': '${diff.inHours}'});
  if (diff.inDays < 30) return context.tr('notifications.daysAgo', {'count': '${diff.inDays}'});
  if (diff.inDays < 365) return context.tr('memory.monthsAgo', {'count': '${(diff.inDays / 30).floor()}'});
  return context.tr('memory.yearsAgo', {'count': '${(diff.inDays / 365).floor()}'});
}
