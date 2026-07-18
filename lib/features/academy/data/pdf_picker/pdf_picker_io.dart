import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'picked_pdf.dart';

/// موبایل/دسکتاپ — انتخاب فایل پی‌دی‌اف با بستهٔ file_picker.
Future<PickedPdf?> pickPdfFile() async {
  // تغییر نهایی: متد pickFiles را مستقیماً از کلاس FilePicker صدا بزنید
  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
    withData: false,
  );
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  return PickedPdf(name: f.name, path: f.path ?? '', sizeBytes: f.size);
}

/// محتوای خام فایلِ انتخاب‌شده را برای آپلود واقعی می‌خواند (از روی مسیر
/// محلی — چون در `pickPdfFile` عمداً `withData: false` بود تا فایل‌های حجیم
/// در حافظه نگه داشته نشوند مگر لحظهٔ آپلود).
Future<List<int>?> readPickedPdfBytes(PickedPdf picked) async {
  if (picked.path.isEmpty) return picked.bytes;
  final file = File(picked.path);
  if (!await file.exists()) return picked.bytes;
  return file.readAsBytes();
}
