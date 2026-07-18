import 'dart:html' as html;
import 'dart:typed_data';
import 'picked_pdf.dart';

/// وب — انتخاب فایل پی‌دی‌اف با input فایل مرورگر (بدون نیاز به file_picker).
/// محتوای فایل همین‌جا (لحظهٔ انتخاب) خوانده می‌شود چون در وب مسیر فایل در
/// دسترس نیست — تنها راه دسترسی بعدی به بایت‌ها همین است.
Future<PickedPdf?> pickPdfFile() async {
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,application/pdf'
    ..multiple = false;
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final f = files.first;
  final reader = html.FileReader();
  reader.readAsArrayBuffer(f);
  await reader.onLoad.first;
  final result = reader.result;
  final bytes = result is Uint8List ? result : Uint8List.fromList(List<int>.from(result as List));
  return PickedPdf(name: f.name, path: '', sizeBytes: f.size, bytes: bytes);
}

/// در وب بایت‌ها همین لحظهٔ انتخاب خوانده شده‌اند — فقط برمی‌گردانیم.
Future<List<int>?> readPickedPdfBytes(PickedPdf picked) async => picked.bytes;
