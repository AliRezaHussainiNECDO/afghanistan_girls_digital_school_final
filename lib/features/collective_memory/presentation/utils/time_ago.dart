/// نمایش زمان نسبی ساده به فارسی (مثلاً «۲ ساعت پیش») — بدون نیاز به
/// پکیج اضافه، فقط برای این بخش.
String timeAgoFa(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inSeconds < 60) return 'همین الان';
  if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
  if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
  if (diff.inDays < 30) return '${diff.inDays} روز پیش';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} ماه پیش';
  return '${(diff.inDays / 365).floor()} سال پیش';
}
