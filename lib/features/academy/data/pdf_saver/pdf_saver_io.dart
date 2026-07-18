import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// موبایل/دسکتاپ — فایل را در پوشهٔ اسناد اپ (زیرپوشهٔ `library/`) ذخیره
/// می‌کند تا برای «مطالعهٔ آفلاین» بماند، و تلاش می‌کند با برنامهٔ پیش‌فرض
/// سیستم بازش کند (اگر ممکن نبود، مشکلی نیست — فایل همچنان ذخیره شده است).
Future<String?> savePdfBytes(String fileName, List<int> bytes) async {
  final dir = await getApplicationDocumentsDirectory();
  final safeName = fileName.trim().isEmpty ? 'book.pdf' : fileName.trim();
  final file = File('${dir.path}/library/$safeName');
  await file.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  try {
    await launchUrl(Uri.file(file.path));
  } catch (_) {
    // بازکردن خودکار ممکن نبود (مثلاً برنامهٔ پی‌دی‌افی نصب نیست)؛ فایل
    // همچنان روی دستگاه ذخیره شده است.
  }
  return file.path;
}
