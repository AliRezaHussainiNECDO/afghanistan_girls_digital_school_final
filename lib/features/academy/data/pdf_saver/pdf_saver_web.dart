import 'dart:html' as html;

/// وب — دانلود مستقیم مرورگر با ساخت یک Blob URL موقت و کلیک برنامه‌ای روی
/// لینک مخفی (بدون نیاز به بستهٔ اضافه).
Future<String?> savePdfBytes(String fileName, List<int> bytes) async {
  final blob = html.Blob([bytes], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = fileName.trim().isEmpty ? 'book.pdf' : fileName.trim()
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return null;
}
