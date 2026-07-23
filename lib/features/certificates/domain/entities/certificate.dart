import 'package:equatable/equatable.dart';

/// استاندارد نصاب آموزشی — برای اعتبار بین‌المللی گواهی‌نامه؛ منبع اصلی این
/// متن سرور است (`certJson` در `exams.ts`)، این‌جا فقط به‌عنوان مقدار
/// پیش‌فرض برای حالت آفلاین/نمایشی (`CertificatesLocalDataSource`) و برای
/// سازگاری با دادهٔ کش‌شدهٔ قدیمی‌تر (بدون این فیلد) نگه داشته شده.
const String kDefaultCurriculumStandardFa =
    'نصاب آموزشی: منطبق با مفردات معارف / سطح ۲ استاندارد بین‌المللی ISCED';
const String kDefaultCurriculumStandardEn =
    'Curriculum Standard: AFG MoE Alignment / ISCED 2011 Level 2';

/// گواهی‌نامهٔ اتمام صنف — پس از ختم هر صنف توسط مدیر برای شاگرد صادر و
/// ارسال می‌شود؛ شاگرد و والدینش می‌توانند آن را مشاهده و دانلود کنند.
class Certificate extends Equatable {
  final String id;

  /// شماره سریال یکتا، مثل AGDS-9-1720094400000
  final String serial;
  final String studentId;
  final String studentName;

  /// صنف تکمیل‌شده (۷ الی ۱۲).
  final int grade;

  /// سال تعلیمی، مثل «۱۴۰۴» یا «2026».
  final String yearLabel;

  /// میانگین نمرات نهایی صنف (۰ تا ۱۰۰).
  final double average;

  /// لقب افتخاری اختیاری، مثل «با درجهٔ اعلی».
  final String honor;

  final DateTime issuedAt;
  final String issuedBy;

  /// استاندارد نصاب آموزشی که شاگرد بر اساس آن ارزیابی شده (به دری/انگلیسی؛
  /// روی خودِ گواهی و صفحهٔ عمومی تأیید اصالت هم نشان داده می‌شود).
  final String curriculumStandardFa;
  final String curriculumStandardEn;

  const Certificate({
    required this.id,
    required this.serial,
    required this.studentId,
    required this.studentName,
    required this.grade,
    required this.yearLabel,
    required this.average,
    required this.honor,
    required this.issuedAt,
    required this.issuedBy,
    this.curriculumStandardFa = kDefaultCurriculumStandardFa,
    this.curriculumStandardEn = kDefaultCurriculumStandardEn,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'serial': serial,
        'studentId': studentId,
        'studentName': studentName,
        'grade': grade,
        'yearLabel': yearLabel,
        'average': average,
        'honor': honor,
        'issuedAt': issuedAt.toIso8601String(),
        'issuedBy': issuedBy,
        'curriculumStandardFa': curriculumStandardFa,
        'curriculumStandardEn': curriculumStandardEn,
      };

  factory Certificate.fromJson(Map<String, dynamic> j) => Certificate(
        id: j['id'] as String,
        serial: j['serial'] as String? ?? '',
        studentId: j['studentId'] as String,
        studentName: j['studentName'] as String? ?? '',
        grade: j['grade'] as int? ?? 7,
        yearLabel: j['yearLabel'] as String? ?? '',
        average: (j['average'] as num?)?.toDouble() ?? 0,
        honor: j['honor'] as String? ?? '',
        issuedAt:
            DateTime.tryParse(j['issuedAt'] as String? ?? '') ?? DateTime.now(),
        issuedBy: j['issuedBy'] as String? ?? 'مدیریت مکتب',
        curriculumStandardFa:
            j['curriculumStandardFa'] as String? ?? kDefaultCurriculumStandardFa,
        curriculumStandardEn:
            j['curriculumStandardEn'] as String? ?? kDefaultCurriculumStandardEn,
      );

  @override
  List<Object?> get props => [id];
}
