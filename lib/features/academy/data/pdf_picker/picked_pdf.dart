/// نتیجهٔ انتخاب یک فایل پی‌دی‌اف — مستقل از پلتفرم (وب/موبایل/دسکتاپ).
class PickedPdf {
  final String name;
  final String path; // در وب خالی است (مرورگر مسیر فایل را نمی‌دهد).
  final int sizeBytes;
  const PickedPdf({required this.name, this.path = '', this.sizeBytes = 0});

  double get sizeMb => sizeBytes / (1024 * 1024);
}
