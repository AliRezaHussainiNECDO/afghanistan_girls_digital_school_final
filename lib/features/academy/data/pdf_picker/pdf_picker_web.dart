import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'picked_pdf.dart';

/// وب — انتخاب فایل پی‌دی‌اف با input فایل مرورگر (بدون نیاز به file_picker).
/// محتوای فایل همین‌جا (لحظهٔ انتخاب) خوانده می‌شود چون در وب مسیر فایل در
/// دسترس نیست — تنها راه دسترسی بعدی به بایت‌ها همین است.
///
/// رفع اشکال: قبلاً از `dart:html` (منسوخ‌شده در فلاتر جدید) استفاده می‌شد؛
/// حالا معادل تایپ‌دار آن یعنی `package:web` + `dart:js_interop` به کار
/// رفته. برخلاف `dart:html`، این بسته Stream راحتِ `.onChange`/`.onLoad` را
/// روی عنصر برنمی‌گرداند — باید مستقیم با `addEventListener` + `Completer`
/// منتظر رویداد ماند.
Future<PickedPdf?> pickPdfFile() async {
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = '.pdf,application/pdf'
    ..multiple = false;

  final changeCompleter = Completer<void>();
  late final JSFunction onChangeListener;
  onChangeListener = (web.Event _) {
    input.removeEventListener('change', onChangeListener);
    if (!changeCompleter.isCompleted) changeCompleter.complete();
  }.toJS;
  input.addEventListener('change', onChangeListener);

  input.click();
  await changeCompleter.future;

  final files = input.files;
  if (files == null || files.length == 0) return null;
  final f = files.item(0);
  if (f == null) return null;

  final reader = web.FileReader();
  final loadCompleter = Completer<void>();
  late final JSFunction onLoadListener;
  late final JSFunction onErrorListener;
  onLoadListener = (web.Event _) {
    reader.removeEventListener('load', onLoadListener);
    reader.removeEventListener('error', onErrorListener);
    if (!loadCompleter.isCompleted) loadCompleter.complete();
  }.toJS;
  onErrorListener = (web.Event _) {
    reader.removeEventListener('load', onLoadListener);
    reader.removeEventListener('error', onErrorListener);
    if (!loadCompleter.isCompleted) {
      loadCompleter.completeError(StateError('خواندن فایل ناموفق بود'));
    }
  }.toJS;
  reader.addEventListener('load', onLoadListener);
  reader.addEventListener('error', onErrorListener);
  reader.readAsArrayBuffer(f);
  await loadCompleter.future;

  final result = reader.result;
  final bytes = result.isA<JSArrayBuffer>()
      ? (result as JSArrayBuffer).toDart.asUint8List()
      : Uint8List(0);
  return PickedPdf(name: f.name, path: '', sizeBytes: f.size.toInt(), bytes: bytes);
}

/// در وب بایت‌ها همین لحظهٔ انتخاب خوانده شده‌اند — فقط برمی‌گردانیم.
Future<List<int>?> readPickedPdfBytes(PickedPdf picked) async => picked.bytes;
