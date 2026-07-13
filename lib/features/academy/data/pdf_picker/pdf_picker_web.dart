import 'dart:html' as html;
import 'picked_pdf.dart';

/// وب — انتخاب فایل پی‌دی‌اف با input فایل مرورگر (بدون نیاز به file_picker).
Future<PickedPdf?> pickPdfFile() async {
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,application/pdf'
    ..multiple = false;
  input.click();
  await input.onChange.first;
  final files = input.files;
  if (files == null || files.isEmpty) return null;
  final f = files.first;
  return PickedPdf(name: f.name, path: '', sizeBytes: f.size);
}
