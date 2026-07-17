import '../../../../core/errors/failures.dart';
import '../../../../core/instructor/instructor_directory.dart';
import '../../../../core/instructor/instructor_invite_store.dart';
import '../../../../core/student/student_directory.dart';
import '../../../../core/student/student_invite_store.dart';
import '../models/app_user_model.dart';
import '../../domain/entities/app_user.dart';
import 'auth_remote_datasource.dart' show AuthDataSource;

/// DataSource ساختگی — طبق بخش ۳.۵ سند (حساب‌های نمایشی) و بخش ۳ب
/// (پروتکل Invite Code). قرارداد مشترک `AuthDataSource` را پیاده می‌کند تا
/// با یک سوییچ در Providerها با `AuthRemoteDataSource` واقعی تعویض شود.
class AuthMockDataSource implements AuthDataSource {
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
      throw const ServerFailure('ایمیل یا رمز اشتباه است', code: 'INVALID_CREDENTIALS');
    }
    // شاخهٔ status=suspended در State Machine ورود (بخش ۳.۲ سند):
    // استادی که مدیر از «مدیریت استادان» مسدود کرده، نمی‌تواند وارد شود.
    if (account.user.role == AppUserRole.seminarInstructor &&
        (InstructorDirectory.instance.byId(account.user.id)?.suspended ?? false)) {
      throw const ServerFailure('حساب شما توسط مدیریت مسدود شده است', code: 'ACCOUNT_SUSPENDED');
    }
    // همان قانون برای شاگردی که مدیر از «مدیریت شاگردان» مسدود/حذف کرده.
    if (account.user.role == AppUserRole.student) {
      final rec = StudentDirectory.instance.byId(account.user.id);
      if (rec != null && rec.status != StudentAccountStatus.active) {
        throw const ServerFailure('حساب شما توسط مدیریت مسدود شده است', code: 'ACCOUNT_SUSPENDED');
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
    // اعتبارسنجی و مصرف کد در «منبع واحد حقیقت» (StudentInviteStore) —
    // همان انباری که مدیر از CMS در آن کد می‌سازد/باطل می‌کند (بخش ۳ب.۳).
    // پیام یکسان برای نامعتبر/مصرف‌شده/باطل/منقضی (بخش ۳ب.۲.۴) + قفل
    // ضد حدس، همه داخل خود Store اعمال می‌شوند.
    try {
      StudentInviteStore.instance.redeem(
        rawCode: inviteCode,
        studentName: '$firstName $lastName'.trim(),
        studentEmail: email,
      );
    } catch (e) {
      throw ServerFailure(e.toString(), code: 'INVALID_INVITE_CODE');
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

  /// ثبت‌نام استاد سمینار — کد دعوت در `InstructorInviteStore` (که مدیر
  /// از CMS می‌سازد) اعتبارسنجی و مصرف می‌شود؛ حساب بلافاصله با نقش
  /// `seminarInstructor` فعال می‌گردد و معلومات استاد روی رکورد کد ثبت
  /// می‌شود تا مدیر ببیند هر کد را چه کسی استفاده کرده است.
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
    // خطاهای خوانا (نامعتبر/مصرف‌شده/باطل/منقضی) به‌صورت String پرتاب
    // می‌شوند و در Repository به Failure تبدیل می‌گردند.
    InstructorInviteStore.instance.redeem(
      rawCode: inviteCode,
      fullName: fullName,
      email: email,
      specialty: specialty,
    );
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
    if (current == null) throw const ServerFailure('وارد نشده‌اید', code: 'UNAUTHORIZED');
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
    if (current == null) throw const ServerFailure('وارد نشده‌اید', code: 'UNAUTHORIZED');
    final account = _accounts[current.email.trim().toLowerCase()];
    if (account == null || account.password != currentPassword) {
      throw const ServerFailure('رمز عبور فعلی نادرست است', code: 'INVALID_CREDENTIALS');
    }
    if (newPassword.length < 8) {
      throw const ServerFailure('رمز عبور جدید باید حداقل ۸ کاراکتر باشد', code: 'WEAK_PASSWORD');
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
