import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_providers.dart';
import '../../domain/entities/app_user.dart';
import '../models/app_user_model.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// قرارداد مشترک DataSource احراز هویت.
///
/// هم `AuthMockDataSource` (فاز ۱ — درون‌حافظه) و هم `AuthRemoteDataSource`
/// (فاز ۲ — Cloudflare Worker) این Interface را پیاده می‌کنند، تا
/// `AuthRepositoryImpl` بدون تغییر با هر دو کار کند و تعویض Mock↔Live فقط با
/// یک سوییچ در Providerها انجام شود (اصل بخش ۲۴.۲ — Dependency Rule).
/// ═══════════════════════════════════════════════════════════════════════════
abstract class AuthDataSource {
  Future<AppUserModel> login(String email, String password);

  Future<AppUserModel> registerStudent({
    required String firstName,
    required String lastName,
    required String email,
    required String inviteCode,
    int? currentGrade,
    String phone,
    String province,
    String dateOfBirth,
    String password,
  });

  Future<AppUserModel> registerParent({
    required String fullName,
    required String email,
    String phone,
    String password,
  });

  Future<AppUserModel> registerInstructor({
    required String fullName,
    required String email,
    required String phone,
    required String specialty,
    required String bio,
    required String inviteCode,
    String password,
  });

  Future<void> forgotPassword(String email);

  /// تغییر رمز با کد ۶ رقمی ارسال‌شده به ایمیل (بخش ۳.۴).
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  /// ارسال مجدد لینک تأیید ایمیل.
  Future<void> resendVerification(String email);

  /// بازیابی نشست ذخیره‌شده هنگام باز شدن اپ (Refresh Token — بخش ۳.۳).
  /// null یعنی نشستی وجود ندارد یا منقضی شده — کاربر باید دوباره وارد شود.
  Future<AppUserModel?> restoreSession();

  /// آپلود عکس پروفایل روی سرور؛ خروجی آدرس کامل عکس یا null (در Mock).
  Future<String?> uploadAvatar(List<int> bytes, String contentType);

  /// ویرایش نام کاربر فعلی — رفع اشکال: قبلاً فقط نشست محلی تغییر می‌کرد.
  Future<AppUserModel> updateProfile({required String firstName, required String lastName});

  /// تغییر رمز عبور — رفع اشکال: قبلاً در UI کاملاً ساختگی بود.
  Future<void> changePassword({required String currentPassword, required String newPassword});

  Future<void> logout();

  AppUserModel? get currentUser;
}

/// پیاده‌سازی واقعی روی Backend — `POST /auth/*` (بخش ۱۹.۱ سند).
///
/// همهٔ خطاها به‌صورت `ApiException` از `ApiClient` بالا می‌آیند و در
/// `AuthRepositoryImpl` به `Failure` دامنه ترجمه می‌شوند.
class AuthRemoteDataSource implements AuthDataSource {
  final ApiClient _api;
  final TokenStore _tokens;

  AuthRemoteDataSource(this._api, this._tokens);

  AppUserModel? _cached;

  @override
  AppUserModel? get currentUser => _cached;

  // ─────────────────────────────── Login ───────────────────────────────

  @override
  Future<AppUserModel> login(String email, String password) async {
    final body = await _api.login(email.trim(), password);
    return _handleAuthPayload(body);
  }

  // ────────────────────────────── Register ─────────────────────────────

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
    String password = '',
  }) async {
    final body = await _api.registerUser({
      'role': 'student',
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      if (currentGrade != null) 'currentGrade': currentGrade,
      'province': province.trim(),
      'dateOfBirth': dateOfBirth,
      'inviteCode': inviteCode.trim(),
    });
    return _handleAuthPayload(body);
  }

  @override
  Future<AppUserModel> registerParent({
    required String fullName,
    required String email,
    String phone = '',
    String password = '',
  }) async {
    final body = await _api.registerUser({
      'role': 'parent',
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
    });
    return _handleAuthPayload(body);
  }

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
    final body = await _api.registerUser({
      'role': 'seminar_instructor',
      'fullName': fullName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'specialty': specialty.trim(),
      'bio': bio.trim(),
      'inviteCode': inviteCode.trim(),
      'password': password,
    });
    return _handleAuthPayload(body);
  }

  // ───────────────────────── Forgot / Logout ───────────────────────────

  @override
  Future<void> forgotPassword(String email) async {
    // پیام یکسان صرف‌نظر از وجود ایمیل (بخش ۳.۴ — ضد User Enumeration)؛
    // پاسخ سرور هرچه باشد، خطا را به کاربر نشان نمی‌دهیم.
    try {
      await _api.post('/auth/forgot-password', data: {'email': email.trim()});
    } on ApiException {
      // عمداً بلعیده می‌شود تا وجود/عدم‌وجود ایمیل لو نرود.
    }
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    // خطاها عمداً بالا می‌روند تا UI پیام دقیق (کد نادرست/منقضی) را نشان دهد.
    await _api.post('/auth/reset-password', data: {
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
  }

  @override
  Future<void> resendVerification(String email) async {
    try {
      await _api.post('/auth/resend-verification', data: {'email': email.trim()});
    } on ApiException {
      // پاسخ سرور همیشه عمومی است؛ خطای شبکه هم نباید UI را بشکند.
    }
  }

  @override
  Future<AppUserModel?> restoreSession() async {
    await _tokens.load();
    final refresh = _tokens.refreshToken;
    if (refresh == null || refresh.isEmpty) return null;
    try {
      // Refresh Rotation (بخش ۳.۳): یک جفت توکن تازه + کاربر برمی‌گردد.
      final body = await _api.refreshToken(refresh);
      return await _handleAuthPayload(body);
    } on ApiException catch (e) {
      if (e.isNetworkError) {
        // آفلاین است — توکن‌ها را نگه می‌داریم تا در اجرای بعدی دوباره تلاش شود.
        return null;
      }
      // توکن باطل/منقضی: نشست محلی پاک می‌شود.
      await _tokens.clear();
      return null;
    }
  }

  @override
  Future<String?> uploadAvatar(List<int> bytes, String contentType) async {
    final body = await _api.uploadBytes('/users/me/avatar', bytes, contentType);
    final raw = (body['avatarUrl'] ?? '').toString();
    if (raw.isEmpty) return null;
    final url = _absoluteUrl(raw);
    final current = _cached;
    if (current != null) {
      _cached = AppUserModel(
        id: current.id,
        email: current.email,
        displayName: current.displayName,
        firstName: current.firstName,
        lastName: current.lastName,
        currentGrade: current.currentGrade,
        role: current.role,
        preferredLanguage: current.preferredLanguage,
        awaitingParentLink: current.awaitingParentLink,
        avatarUrl: url,
        emailVerified: current.emailVerified,
      );
    }
    return url;
  }

  @override
  Future<AppUserModel> updateProfile({required String firstName, required String lastName}) async {
    final body = await _api.patch('/auth/me', data: {
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
    });
    final userJson = (body['user'] is Map) ? Map<String, dynamic>.from(body['user'] as Map) : body;
    final user = _userFromApi(userJson);
    _cached = user;
    return user;
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _api.post('/auth/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  @override
  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } on ApiException {
      // حتی اگر سرور در دسترس نبود، نشست محلی باید پاک شود.
    } finally {
      _cached = null;
      await _tokens.clear();
    }
  }

  // ─────────────────────────── کمک‌کننده‌ها ─────────────────────────────

  /// پاسخ Auth را پردازش می‌کند: Tokenها را ذخیره و `AppUserModel` را می‌سازد.
  ///
  /// شکل انتظاری پاسخ (منعطف نسبت به `data`-wrapper احتمالی):
  /// ```json
  /// { "user": {...}, "accessToken": "...", "refreshToken": "..." }
  /// ```
  Future<AppUserModel> _handleAuthPayload(Map<String, dynamic> body) async {
    final payload = (body['data'] is Map)
        ? Map<String, dynamic>.from(body['data'] as Map)
        : body;

    final access = (payload['accessToken'] ?? payload['token'] ?? payload['access_token'])
        ?.toString();
    final refresh =
        (payload['refreshToken'] ?? payload['refresh_token'])?.toString();
    if (access != null && access.isNotEmpty) {
      await _tokens.saveTokens(access: access, refresh: refresh);
    }

    final userJson = (payload['user'] is Map)
        ? Map<String, dynamic>.from(payload['user'] as Map)
        : payload;
    final user = _userFromApi(userJson);
    _cached = user;
    return user;
  }

  /// نگاشت مقاوم از JSON کاربر سرور (snake_case، بخش ۱۷.۱) به `AppUserModel`.
  /// چون Backend ممکن است کلیدها را کمی متفاوت بفرستد، هر دو حالت را می‌پذیریم.
  AppUserModel _userFromApi(Map<String, dynamic> j) {
    final first = (j['firstName'] ?? j['first_name'] ?? '').toString();
    final last = (j['lastName'] ?? j['last_name'] ?? '').toString();
    final display = (j['displayName'] ?? j['display_name'] ?? '').toString();
    final fullName = display.isNotEmpty
        ? display
        : [first, last].where((s) => s.trim().isNotEmpty).join(' ').trim();

    final gradeRaw = j['currentGrade'] ?? j['current_grade'];
    final grade = gradeRaw is int
        ? gradeRaw
        : (gradeRaw is String ? int.tryParse(gradeRaw) : null);

    final avatarRaw = (j['avatarUrl'] ?? j['avatar_url'])?.toString();

    return AppUserModel(
      id: (j['id'] ?? '').toString(),
      email: (j['email'] ?? '').toString(),
      displayName: fullName.isEmpty ? (j['email'] ?? 'کاربر').toString() : fullName,
      firstName: first,
      lastName: last,
      currentGrade: grade,
      role: _roleFromApi((j['role'] ?? j['role_key'] ?? j['role_id'])?.toString()),
      preferredLanguage:
          (j['preferredLanguage'] ?? j['preferred_language'] ?? 'fa').toString(),
      awaitingParentLink:
          j['awaitingParentLink'] == true || j['awaiting_parent_link'] == true,
      avatarUrl: (avatarRaw == null || avatarRaw.isEmpty) ? null : _absoluteUrl(avatarRaw),
      emailVerified: j['emailVerified'] == true || j['email_verified'] == true,
    );
  }

  /// آدرس نسبی سرور (مثل `/files/avatars/x.jpg`) را به آدرس کامل تبدیل می‌کند.
  String _absoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$kApiBaseUrl$url';
  }

  AppUserRole _roleFromApi(String? role) {
    switch (role) {
      case 'super_admin':
      case 'superAdmin':
        return AppUserRole.superAdmin;
      case 'parent':
        return AppUserRole.parent;
      case 'seminar_instructor':
      case 'seminarInstructor':
        return AppUserRole.seminarInstructor;
      case 'student':
      default:
        return AppUserRole.student;
    }
  }
}
