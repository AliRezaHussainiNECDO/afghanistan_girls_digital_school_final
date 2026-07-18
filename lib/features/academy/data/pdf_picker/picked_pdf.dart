import 'dart:typed_data';

/// نتیجهٔ انتخاب یک فایل پی‌دی‌اف — مستقل از پلتفرم (وب/موبایل/دسکتاپ).
class PickedPdf {
  final String name;
  final String path; // در وب خالی است (مرورگر مسیر فایل را نمی‌دهد).
  final int sizeBytes;

  /// محتوای خام فایل — فقط در وب همین‌جا پر می‌شود (چون مسیر فایل در دسترس
  /// نیست)؛ در موبایل/دسکتاپ بعداً از روی [path] با `readPickedPdfBytes`
  /// خوانده می‌شود تا در حافظه دوبار نگه‌داری نشود.
  final Uint8List? bytes;

  const PickedPdf({required this.name, this.path = '', this.sizeBytes = 0, this.bytes});

  double get sizeMb => sizeBytes / (1024 * 1024);
}
