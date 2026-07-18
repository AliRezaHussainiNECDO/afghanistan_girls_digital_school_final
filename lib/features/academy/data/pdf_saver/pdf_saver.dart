// ذخیرهٔ فایل پی‌دی‌اف دانلودشده به‌صورت چندسکویی:
//   • موبایل/دسکتاپ (dart.library.io) → در پوشهٔ اسناد اپ ذخیره و با
//     برنامهٔ پیش‌فرض سیستم باز می‌شود.
//   • وب (dart.library.html) → دانلود مستقیم مرورگر (Blob + لینک مخفی).
//   • در غیر این صورت → stub بی‌اثر.
// این جداسازی مطابق همان الگوی `pdf_picker/` است تا کد مشترک UI هیچ‌وقت
// مستقیماً به dart:io یا dart:html وابسته نشود.
//
// هر پیاده‌سازی این تابع را تأمین می‌کند:
//   Future<String?> savePdfBytes(String fileName, List<int> bytes);
// خروجی: مسیر محلیِ ذخیره‌شده (فقط موبایل/دسکتاپ) یا null (وب/ناموفق).
export 'pdf_saver_stub.dart'
    if (dart.library.io) 'pdf_saver_io.dart'
    if (dart.library.html) 'pdf_saver_web.dart';
