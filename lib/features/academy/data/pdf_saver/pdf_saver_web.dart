import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// وب — دانلود مستقیم مرورگر با ساخت یک Blob URL موقت و کلیک برنامه‌ای روی
/// لینک مخفی (بدون نیاز به بستهٔ اضافه).
///
/// رفع اشکال: قبلاً از `dart:html` (منسوخ‌شده در فلاتر جدید) استفاده می‌شد؛
/// حالا معادل تایپ‌دار آن یعنی `package:web` + `dart:js_interop` به کار
/// رفته — همان رفتار، بدون هشدار deprecation.
Future<String?> savePdfBytes(String fileName, List<int> bytes) async {
  final data = Uint8List.fromList(bytes);
  final blobParts = <JSAny>[data.toJS].toJS;
  final blob = web.Blob(blobParts, web.BlobPropertyBag(type: 'application/pdf'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = fileName.trim().isEmpty ? 'book.pdf' : fileName.trim()
    ..style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return null;
}
