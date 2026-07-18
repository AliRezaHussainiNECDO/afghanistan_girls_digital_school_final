import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/certificate.dart';
import '../widgets/certificate_view.dart';

/// نمایش تمام‌صفحهٔ گواهی‌نامه + دانلود به‌صورت PDF یا عکس PNG.
/// خروجی از خود ویجت رندر می‌شود، بنابراین متن دری/RTL دقیقاً همان‌طور که
/// در اپ دیده می‌شود در فایل خروجی هم ظاهر می‌گردد.
class CertificateViewerScreen extends StatefulWidget {
  final Certificate certificate;
  const CertificateViewerScreen({super.key, required this.certificate});

  @override
  State<CertificateViewerScreen> createState() =>
      _CertificateViewerScreenState();
}

class _CertificateViewerScreenState extends State<CertificateViewerScreen> {
  final GlobalKey _certKey = GlobalKey();
  bool _saving = false;

  Future<Uint8List?> _capturePng() async {
    try {
      final boundary = _certKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<void> _save({required bool asPdf}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final png = await _capturePng();
      if (png == null) {
        _toast(context.tr('certificates.prepareImageFailed'));
        return;
      }

      Uint8List bytes;
      String ext;
      if (asPdf) {
        // PNG رندرشده داخل یک صفحهٔ PDF افقی A4 جاسازی می‌شود.
        final doc = PdfDocument();
        doc.pageSettings.orientation = PdfPageOrientation.landscape;
        doc.pageSettings.margins.all = 0;
        final page = doc.pages.add();
        final size = page.getClientSize();
        page.graphics.drawImage(
            PdfBitmap(png), Rect.fromLTWH(0, 0, size.width, size.height));
        bytes = Uint8List.fromList(await doc.save());
        doc.dispose();
        ext = 'pdf';
      } else {
        bytes = png;
        ext = 'png';
      }

      if (kIsWeb) {
        _toast(context.tr('certificates.webDownloadUnavailable'));
        return;
      }

      final fileName =
          '${context.tr('certificates.fileNamePrefix')}-${widget.certificate.grade}-${widget.certificate.serial}.$ext';
      final path = await FilePicker.saveFile(
        dialogTitle: context.tr('certificates.saveDialogTitle'),
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: [ext],
        bytes: bytes,
      );
      if (path == null) return; // کاربر منصرف شد

      // در دسکتاپ ممکن است فقط مسیر برگردد — بایت‌ها را خودمان می‌نویسیم.
      final file = File(path);
      if (!await file.exists() || (await file.length()) == 0) {
        await file.writeAsBytes(bytes);
      }
      _toast(context.tr('certificates.savedSuccess'));
    } catch (e) {
      _toast(context.tr('certificates.saveError', {'error': '$e'}));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF232323),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: Text(context.tr('certificates.title'),
              style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: RepaintBoundary(
                    key: _certKey,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: CertificateView(certificate: widget.certificate),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _save(asPdf: true),
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.picture_as_pdf_rounded),
                        label: Text(context.tr('certificates.downloadPdf')),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _saving ? null : () => _save(asPdf: false),
                        icon: const Icon(Icons.image_rounded),
                        label: Text(context.tr('certificates.saveImage')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
