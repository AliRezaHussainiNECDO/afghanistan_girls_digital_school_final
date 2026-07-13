/// ثابت‌های سراسری اپ — طبق بخش‌های ۲، ۶.۱، و ۳.۱ سند.
class AppConstants {
  AppConstants._();

  static const String appName = 'مکتب دیجیتال دختران افغانستان';
  static const String appNameEn = 'Afghanistan Girls Digital School';

  /// صنوف ۷ تا ۱۲ (بخش ۶.۱ سند).
  static const List<int> grades = [7, 8, 9, 10, 11, 12];

  /// ۱۰ مضمون ثابت هر صنف (بخش ۶.۱ سند).
  static const List<String> subjectKeysFa = [
    'ریاضی',
    'فزیک',
    'کیمیا',
    'بیولوژی',
    'انگلیسی',
    'ادبیات دری',
    'تاریخ',
    'جغرافیه',
    'تعلیمات اسلامی',
    'کمپیوتر ساینس',
  ];

  /// ۳۴ ولایت افغانستان (بخش ۳.۱ سند) — برای Dropdown ثبت‌نام.
  static const List<String> provinces = [
    'کابل', 'هرات', 'بلخ', 'قندهار', 'ننگرهار', 'بامیان', 'بدخشان', 'بادغیس',
    'بغلان', 'پروان', 'پنجشیر', 'تخار', 'جوزجان', 'خوست', 'دایکندی', 'زابل',
    'سرپل', 'سمنگان', 'غزنی', 'غور', 'فراه', 'فاریاب', 'کاپیسا', 'کندز',
    'کنر', 'کنرها', 'لغمان', 'لوگر', 'میدان وردک', 'نورستان', 'نیمروز',
    'هلمند', 'پکتیا', 'پکتیکا',
  ];

  static const int minRegistrationAge = 10;
  static const int maxRegistrationAge = 20;

  /// حساب‌های نمایشی Mock — طبق بخش ۳.۵ سند.
  static const String demoStudentEmail = 'student@demo.com';
  static const String demoAdminEmail = 'admin@demo.com';
  static const String demoParentEmail = 'parent@demo.com';
  static const String demoInstructorEmail = 'instructor@demo.com';
}
