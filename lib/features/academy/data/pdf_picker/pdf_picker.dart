// انتخاب فایل پی‌دی‌اف به‌صورت چندسکویی:
//   • موبایل/دسکتاپ (dart.library.io) → از بستهٔ file_picker استفاده می‌شود.
//   • وب (dart.library.html) → از input فایل مرورگر استفاده می‌شود.
//   • در غیر این صورت → stub که null برمی‌گرداند.
// این جداسازی باعث می‌شود book_sheets هیچ‌وقت مستقیماً به file_picker یا
// dart:io/dart:html وابسته نشود و روی هر سکویی کامپایل گردد.
//
// هر پیاده‌سازی این تابع را تأمین می‌کند: Future<PickedPdf?> pickPdfFile();
export 'pdf_picker_stub.dart'
    if (dart.library.io) 'pdf_picker_io.dart'
    if (dart.library.html) 'pdf_picker_web.dart';
