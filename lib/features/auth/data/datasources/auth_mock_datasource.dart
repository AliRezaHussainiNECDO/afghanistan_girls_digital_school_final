import '../../../../core/errors/failures.dart';
import '../../../../core/instructor/instructor_directory.dart';
import '../../../../core/student/student_directory.dart';
import '../models/app_user_model.dart';
import '../../domain/entities/app_user.dart';
import 'auth_remote_datasource.dart' show AuthDataSource;

/// DataSource ساختگی — طبق بخش ۳.۵ سند (حساب‌های نمایشی) و بخش ۳ب
/// (پروتکل Invite Code). قرارداد مشترک `AuthDataSource` را پیاده می‌کند تا
/// با یک سوییچ در Providerها با `AuthRemoteDataSource` واقعی تعویض شود.
class AuthMockDataSource implements AuthDataSource {
  final String localeCode;
  AuthMockDataSource({this.localeCode = 'fa'});

  static const Map<String, Map<String, String>> _i18n = {
    'fa': {
      'invalidCredentials': 'ایمیل یا رمز اشتباه است',
      'accountSuspended': 'حساب شما توسط مدیریت مسدود شده است',
      'notLoggedIn': 'وارد نشده‌اید',
      'wrongCurrentPassword': 'رمز عبور فعلی نادرست است',
      'weakPassword': 'رمز عبور جدید باید حداقل ۸ کاراکتر باشد',
      'emptyInviteCode': 'کد دعوت را وارد کنید',
    },
    'en': {
      'invalidCredentials': 'Incorrect email or password',
      'accountSuspended': 'Your account has been suspended by the administration',
      'notLoggedIn': 'You are not logged in',
      'wrongCurrentPassword': 'The current password is incorrect',
      'weakPassword': 'The new password must be at least 8 characters',
      'emptyInviteCode': 'Please enter an invite code',
    },
    'ps': {
      'invalidCredentials': 'بریښنالیک یا پټنوم ناسم دی',
      'accountSuspended': 'ستاسو حساب د ادارې لخوا بند شوی دی',
      'notLoggedIn': 'تاسو ننوتلي نه یاست',
      'wrongCurrentPassword': 'اوسنی پټنوم ناسم دی',
      'weakPassword': 'نوی پټنوم باید لږ تر لږه ۸ توري ولري',
      'emptyInviteCode': 'مهرباني وکړئ د بلنې کوډ ولیکئ',
    },
    'fr': {
      'invalidCredentials': 'E-mail ou mot de passe incorrect',
      'accountSuspended': 'Votre compte a été suspendu par l’administration',
      'notLoggedIn': 'Vous n’êtes pas connecté',
      'wrongCurrentPassword': 'Le mot de passe actuel est incorrect',
      'weakPassword': 'Le nouveau mot de passe doit comporter au moins 8 caractères',
      'emptyInviteCode': 'Veuillez saisir un code d’invitation',
    },
  };

  String _t(String key) => _i18n[localeCode]?[key] ?? _i18n['fa']![key]!;

  // تنها حساب ورودِ از پیش ساخته: مدیر کل. حساب‌های نمایشی حذف شدند —
  // شاگرد/والد/استاد فقط از راه ثبت‌نام (با کد دعوت) حساب می‌سازند.
  static final Map<String, ({String password, AppUserModel user})> _accounts = {
    'alireza.necdo@gmail.com': (
      password: 'loveNJ@\$2026',
      user: const AppUserModel(
        id: 'u_super_admin_ali',
        email: 'alireza.necdo@gmail.com',
        displayName: 'Ali Reza Hussaini',
        firstName: 'Ali Reza',
        lastName: 'Hussaini',
        role: AppUserRole.superAdmin,
      ),
    ),
  };

  AppUserModel? _currentUser;

  @override
  Future<AppUserModel> login(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final account = _accounts[email.trim().toLowerCase()];
    if (account == null || account.password != password) {
      throw ServerFailure(_t('invalidCredentials'), code: 'INVALID_CREDENTIALS');
    }
    // شاخهٔ status=suspended در State Machine ورود (بخش ۳.۲ سند):
    // استادی که مدیر از «مدیریت استادان» مسدود کرده، نمی‌تواند وارد شود.
    if (account.user.role == AppUserRole.seminarInstructor &&
        (InstructorDirectory.instance.byId(account.user.id)?.suspended ?? false)) {
      throw ServerFailure(_t('accountSuspended'), code: 'ACCOUNT_SUSPENDED');
    }
    // همان قانون برای شاگردی که مدیر از «مدیریت شاگردان» مسدود/حذف کرده.
    if (account.user.role == AppUserRole.student) {
      final rec = StudentDirectory.instance.byId(account.user.id);
      if (rec != null && rec.status != StudentAccountStatus.active) {
        throw ServerFailure(_t('accountSuspended'), code: 'ACCOUNT_SUSPENDED');
      }
    }
    _currentUser = account.user;
    return account.user;
  }

  @override
  Future<AppUserModel> registerStudent({
    required String firstName,
    required String lastName,
    required String email,
    required String inviteCode,
    int? currentGrade,
    String phone = '',
    String province = '',
    String dateOfBirth = '',
    String password = '', // در Mock استفاده نمی‌شود؛ برای هم‌امضایی با Remote.
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    // رفع اشکال (۲۴ جولای): اعتبارسنجی واقعیِ کد دعوت دیگر اینجا شبیه‌سازی
    // نمی‌شود — منبع واحد حقیقتِ کدهای دعوت همیشه جدول `invite_codes` در
    // D1 بوده و فقط از طریق `POST /api/auth/register` واقعی بررسی می‌شود
    // (`AuthRemoteDataSource`). حالت Mock فقط برای پیش‌نمایش UI بدون سرور
    // است؛ همین‌جا فقط یک اعتبارسنجی صوریِ سبک (کد خالی نباشد) کافی است.
    if (inviteCode.trim().isEmpty) {
      throw ServerFailure(_t('emptyInviteCode'), code: 'INVALID_INVITE_CODE');
    }
    final user = AppUserModel(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: '$firstName $lastName',
      firstName: firstName,
      lastName: lastName,
      currentGrade: currentGrade,
      role: AppUserRole.student,
    );
    // ثبت در دفترچهٔ شاگردان — تا بلافاصله با معلومات حقیقی ثبت‌نام در
    // «مدیریت شاگردان» پنل مدیر دیده شود (بخش ۱۵.۲ سند).
    StudentDirectory.instance.register(
      id: user.id,
      fullName: '$firstName $lastName',
      email: email,
      phone: phone,
      province: province,
      birthDate: DateTime.tryParse(dateOfBirth),
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<AppUserModel> registerParent({
    required String fullName,
    required String email,
    String phone = '',
    String password = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final user = AppUserModel(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: fullName,
      role: AppUserRole.parent,
      awaitingParentLink: true, // طبق بخش ۳.۶: تا لینک نشدن فرزند، awaiting_link
    );
    _currentUser = user;
    return user;
  }

  /// ثبت‌نام استاد سمینار — رفع اشکال (۲۴ جولای): کد دعوت دیگر با
  /// `InstructorInviteStore` محلی اعتبارسنجی نمی‌شود (منبع واحد حقیقتِ
  /// واقعی جدول `invite_codes` در D1 است، فقط از راه `AuthRemoteDataSource`
  /// قابل‌بررسی). این مسیر Mock فقط برای پیش‌نمایش UI است.
  @override
  Future<AppUserModel> registerInstructor({
    required String fullName,
    required String email,
    required String phone,
    required String specialty,
    required String bio,
    required String inviteCode,
    String password = '',
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (inviteCode.trim().isEmpty) {
      throw ServerFailure(_t('emptyInviteCode'), code: 'INVALID_INVITE_CODE');
    }
    final user = AppUserModel(
      id: 'u-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      displayName: fullName,
      role: AppUserRole.seminarInstructor,
    );
    // ثبت در دفترچهٔ استادان تا بلافاصله در «مدیریت استادان» پنل مدیر
    // دیده شود (بخش ۱۵.۲ سند).
    InstructorDirectory.instance.register(
      id: user.id,
      fullName: fullName,
      email: email,
      phone: phone,
      specialty: specialty,
      bio: bio,
    );
    _currentUser = user;
    return user;
  }

  @override
  Future<void> forgotPassword(String email) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // طبق بخش ۳.۴: پیام یکسان صرف‌نظر از وجود ایمیل — اینجا همیشه موفق برمی‌گردد.
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    // در Mock سروری وجود ندارد؛ برای تست UI همیشه موفق برمی‌گردد.
  }

  @override
  Future<void> resendVerification(String email) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }

  @override
  Future<AppUserModel?> restoreSession() async => null; // Mock نشست پایدار ندارد.

  @override
  Future<String?> uploadAvatar(List<int> bytes, String contentType) async => null;

  @override
  Future<AppUserModel> updateProfile({required String firstName, required String lastName}) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final current = _currentUser;
    if (current == null) throw ServerFailure(_t('notLoggedIn'), code: 'UNAUTHORIZED');
    final fullName = [firstName, lastName].where((s) => s.trim().isNotEmpty).join(' ').trim();
    final updated = AppUserModel(
      id: current.id,
      email: current.email,
      displayName: fullName.isEmpty ? current.displayName : fullName,
      firstName: firstName,
      lastName: lastName,
      currentGrade: current.currentGrade,
      role: current.role,
      preferredLanguage: current.preferredLanguage,
      awaitingParentLink: current.awaitingParentLink,
      avatarUrl: current.avatarUrl,
      emailVerified: current.emailVerified,
    );
    _currentUser = updated;
    return updated;
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final current = _currentUser;
    if (current == null) throw ServerFailure(_t('notLoggedIn'), code: 'UNAUTHORIZED');
    final account = _accounts[current.email.trim().toLowerCase()];
    if (account == null || account.password != currentPassword) {
      throw ServerFailure(_t('wrongCurrentPassword'), code: 'INVALID_CREDENTIALS');
    }
    if (newPassword.length < 8) {
      throw ServerFailure(_t('weakPassword'), code: 'WEAK_PASSWORD');
    }
    _accounts[current.email.trim().toLowerCase()] = (password: newPassword, user: account.user);
  }

  @override
  Future<void> logout() async {
    _currentUser = null;
  }

  @override
  AppUserModel? get currentUser => _currentUser;
}
