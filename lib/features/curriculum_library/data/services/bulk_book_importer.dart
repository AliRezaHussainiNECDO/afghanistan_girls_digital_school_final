import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../../../../core/localization/translations/en.dart';
import '../../../../core/localization/translations/fa.dart';
import '../../../../core/localization/translations/fr.dart';
import '../../../../core/localization/translations/ps.dart';
import '../../../../shared_models/subject.dart';
import '../datasources/curriculum_library_local_datasource.dart';

/// ورود دسته‌ای کتاب‌های PDF نصاب تعلیمی (صنف ۷ الی ۱۲) — کاربر همهٔ
/// فایل‌های دانلودشده (مثلاً از اسکریپت download_curriculum.ps1) را یک‌جا
/// انتخاب می‌کند و مضمون + صنف هر فایل از روی نامش تشخیص داده می‌شود.
///
/// الگوهای پشتیبانی‌شدهٔ نام فایل: `Math_G7.pdf`, `Physic_G10.pdf`,
/// `Islamic_Study_G8.pdf`, `ریاضی-صنف7.pdf` و مشابه آن‌ها.
enum BulkItemStatus { pending, importing, done, failed, skipped }

class BulkImportItem {
  final PlatformFile file;
  String? subjectId;
  int? grade;
  BulkItemStatus status;
  String? message;
  int pageCount;
  int charCount;

  BulkImportItem(this.file)
      : status = BulkItemStatus.pending,
        pageCount = 0,
        charCount = 0 {
    final d = BulkBookImporter.detect(file.name);
    subjectId = d.$1;
    grade = d.$2;
  }
}

class BulkBookImporter {
  final CurriculumLibraryLocalDataSource library;
  final String localeCode;
  BulkBookImporter(this.library, {this.localeCode = 'fa'});

  Map<String, String> get _strings => switch (localeCode) {
        'ps' => psStrings,
        'en' => enStrings,
        'fr' => frStrings,
        _ => faStrings,
      };

  String _t(String key, [Map<String, String>? params]) {
    var text = _strings[key] ?? key;
    if (params != null) {
      for (final e in params.entries) {
        text = text.replaceAll('{${e.key}}', e.value);
      }
    }
    return text;
  }

  /// نگاشت توکن‌های نام فایل (اسکریپت وزارت معارف) → شناسهٔ مضمون در اپ.
  static const Map<String, String> _tokenToSubject = {
    'math': 'math',
    'ریاضی': 'math',
    'physic': 'physics',
    'physics': 'physics',
    'فزیک': 'physics',
    'chemistry': 'chemistry',
    'کیمیا': 'chemistry',
    'biology': 'biology',
    'بیولوژی': 'biology',
    'english': 'english',
    'انگلیسی': 'english',
    'dari': 'dari_lit',
    'دری': 'dari_lit',
    'history': 'history',
    'تاریخ': 'history',
    'geography': 'geography',
    'جغرافیه': 'geography',
    'islamic': 'islamic',
    'اسلامی': 'islamic',
    'computer': 'cs',
    'کمپیوتر': 'cs',
  };

  /// تشخیص (subjectId, grade) از نام فایل؛ هرکدام نامشخص بود null برمی‌گردد.
  static (String?, int?) detect(String fileName) {
    final lower = fileName.toLowerCase();

    String? subjectId;
    for (final e in _tokenToSubject.entries) {
      if (lower.contains(e.key)) {
        subjectId = e.value;
        break;
      }
    }

    int? grade;
    // اعداد فارسی را به لاتین تبدیل کن، بعد الگوهای G7 / _7 / صنف7 را بگرد.
    const fa = '۰۱۲۳۴۵۶۷۸۹';
    var normalized = lower;
    for (var i = 0; i < fa.length; i++) {
      normalized = normalized.replaceAll(fa[i], '$i');
    }
    final m = RegExp(r'(?:g|grade|صنف|_|-|\s)(1[0-2]|[7-9])(?![0-9])')
        .firstMatch(normalized);
    if (m != null) grade = int.parse(m.group(1)!);

    return (subjectId, grade);
  }

  String subjectNameFa(String? subjectId) {
    if (subjectId == null) return _t('bulkImporter.unknownSubject');
    return mockSubjects
        .firstWhere((s) => s.id == subjectId, orElse: () => mockSubjects.first)
        .nameFa;
  }

  /// ورود یک فایل — متن PDF استخراج و به کتابخانهٔ نصاب اضافه می‌شود.
  Future<void> importItem(BulkImportItem item) async {
    if (item.subjectId == null || item.grade == null) {
      item.status = BulkItemStatus.skipped;
      item.message = _t('bulkImporter.subjectGradeNotDetected');
      return;
    }
    final bytes = item.file.bytes;
    if (bytes == null) {
      item.status = BulkItemStatus.failed;
      item.message = _t('bulkImporter.fileContentNotRead');
      return;
    }
    try {
      final document = PdfDocument(inputBytes: bytes);
      final text = PdfTextExtractor(document).extractText();
      item.pageCount = document.pages.count;
      document.dispose();

      if (text.trim().length < 200) {
        item.status = BulkItemStatus.failed;
        item.message = _t('bulkImporter.noExtractableText');
        return;
      }
      item.charCount = text.length;
      await library.addBook(
        subjectId: item.subjectId!,
        title: _t('bulkImporter.generatedBookTitle',
            {'subject': subjectNameFa(item.subjectId), 'grade': '${item.grade}'}),
        pageCount: item.pageCount,
        gradeId: item.grade!,
        extractedText: text,
      );
      item.status = BulkItemStatus.done;
      item.message = _t('bulkImporter.importedStats',
          {'pages': '${item.pageCount}', 'chars': '${(item.charCount / 1000).round()}'});
    } catch (e) {
      item.status = BulkItemStatus.failed;
      item.message = _t('bulkImporter.pdfProcessErrorWithReason', {'error': '$e'});
    }
  }
}
