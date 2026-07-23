import 'package:dio/dio.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ApiClient — لایهٔ شبکهٔ مرکزی اپ (بخش ۲۴.۴ سند: `core/network/`).
///
/// یک Wrapper نازک اما کامل روی `Dio` که:
///   • پیکربندی پایه (baseUrl، timeoutها، headerها) را متمرکز می‌کند،
///   • Token احراز هویت (JWT — بخش ۳.۳) را خودکار به هر درخواست می‌چسباند،
///   • خطاهای خام Dio را به `ApiException` تایپ‌دار و خوانا تبدیل می‌کند
///     (۴۰۰/۴۰۱/۴۰۳/۵۰۰ + timeout + قطع شبکه)،
///   • متدهای استاندارد GET/POST/PUT/DELETE و یک متد صریح `registerUser`
///     برای `/auth/register` (بخش ۱۹.۱ سند) ارائه می‌دهد.
///
/// این کلاس **مستقل از Flutter و Riverpod** است تا در تست‌ها به‌سادگی با یک
/// `Dio` Mock جایگزین شود (اصل بخش ۲۴.۲ — Dependency Rule).
/// ═══════════════════════════════════════════════════════════════════════════

/// آدرس پایهٔ API (Cloudflare Worker + Tunnel).
///
/// در Build تولیدی بهتر است این مقدار با
/// `--dart-define=API_BASE_URL=https://api.afghanistangirlsdigitalschool.org/api/v1`
/// تزریق شود؛ مقدار زیر پیش‌فرضِ امن است اگر تزریق نشده باشد.
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // رفع اشکال حیاتی «ورود ناموفق»: دامنهٔ اشتراکیِ *.workers.dev احتمالاً
  // روی شبکهٔ برخی کاربران (مثلاً افغانستان) فیلتر است — تأیید شد با تست
  // مستقیم: همان دامنه از یک شبکهٔ دیگر جواب می‌دهد ولی روی گوشیِ کاربرِ
  // گزارش‌دهنده، حتی ریشهٔ همان دامنه هم باز نمی‌شود. دامنهٔ اختصاصیِ خودِ
  // مکتب (که در wrangler.toml هم اکنون Route شده) این ریسک را ندارد.
  defaultValue: 'https://api.afghanistangirlsdigitalschool.org/api/v1',
);

/// آدرس عمومیِ برندشدهٔ تأیید اصالت گواهی‌نامه (پشت QR روی سرتیفیکت) —
/// جدا از [kApiBaseUrl] چون این یکی باید همیشه دامنهٔ اصلی/برندِ مکتب باشد
/// (نه آدرس فنی Workers.dev)، حتی وقتی [kApiBaseUrl] هنوز به دامنهٔ
/// سفارشی سوییچ نشده. Route مربوطه (`/verify/*` روی ریشهٔ دامنه) در
/// `backend/wrangler.toml` فعال است.
const String kCertVerifyBaseUrl = String.fromEnvironment(
  'CERT_VERIFY_BASE_URL',
  defaultValue: 'https://afghanistangirlsdigitalschool.org',
);

/// امضای تابعی که Access Token فعلی را برمی‌گرداند (یا null اگر کاربر وارد
/// نشده). با این الگو، ApiClient به هیچ سیستم ذخیره‌سازی خاصی وابسته نیست؛
/// در فاز بعد می‌توان آن را به `secure storage`/`shared_preferences` وصل کرد.
typedef TokenProvider = String? Function();

/// امضای Callback هنگام دریافت 401 (Token منقضی/نامعتبر) — برای Logout خودکار
/// یا تلاش Refresh در لایهٔ بالاتر.
typedef UnauthorizedCallback = void Function();

/// خطای تایپ‌دار شبکه/سرور. لایهٔ Repository این را می‌گیرد و به
/// `Failure` دامنه (بخش `core/errors/failures.dart`) ترجمه می‌کند.
class ApiException implements Exception {
  /// کد وضعیت HTTP (اگر پاسخی رسیده باشد； برای timeout/قطع شبکه null است).
  final int? statusCode;

  /// کد خطای برنامه‌ای از بدنهٔ پاسخ (قرارداد خطای بخش ۱۹.۱۰:
  /// `error.code` مثل `INVALID_INVITE_CODE`, `GRADE_LOCKED`).
  final String? code;

  /// پیام خوانا برای کاربر (ترجیحاً پیام فارسی سرور، در غیر این صورت پیش‌فرض).
  final String message;

  /// نوع خطا برای تصمیم‌گیری در UI (مثلاً نمایش دکمهٔ «تلاش دوباره» برای شبکه).
  final ApiErrorType type;

  const ApiException({
    required this.message,
    required this.type,
    this.statusCode,
    this.code,
  });

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isServerError => (statusCode ?? 0) >= 500;
  bool get isNetworkError => type == ApiErrorType.network || type == ApiErrorType.timeout;

  @override
  String toString() =>
      'ApiException($type, status: $statusCode, code: $code, message: $message)';
}

enum ApiErrorType {
  /// 400 — درخواست نامعتبر / خطای اعتبارسنجی سمت سرور.
  badRequest,

  /// 401 — عدم احراز هویت (Token غایب/منقضی/نامعتبر).
  unauthorized,

  /// 403 — احراز هویت شده اما بدون مجوز (RBAC — بخش ۲.۲).
  forbidden,

  /// 404 — منبع یافت نشد.
  notFound,

  /// 409 — تعارض (مثلاً ایمیل تکراری — بخش ۳.۱).
  conflict,

  /// 429 — اتمام موقت سهمیهٔ رایگان هوش مصنوعی (Gemini Free Tier) یا
  /// Rate Limit سرور — UI باید پیام محترمانهٔ «قفل موقت» نشان دهد.
  rateLimited,

  /// 5xx — خطای داخلی سرور.
  server,

  /// Timeout در اتصال/ارسال/دریافت.
  timeout,

  /// قطع شبکه / عدم دسترسی به میزبان / لغو درخواست.
  network,

  /// خطای ناشناخته/پارس‌نشده.
  unknown,
}

class ApiClient {
  late final Dio _dio;
  final TokenProvider? _tokenProvider;
  final UnauthorizedCallback? _onUnauthorized;

  /// کد زبان فعال اپ (fa/en/ps/fr) — برای پیام‌های خطای این کلاینت. این کلاس
  /// همچنان مستقل از Flutter/Riverpod است؛ فقط یک مقدار ساده‌ی رشته‌ای
  /// می‌گیرد (بدون وابستگی مستقیم به BuildContext یا Provider).
  final String localeCode;

  static const Map<String, Map<String, String>> _i18n = {
    'fa': {
      'unexpectedError': 'خطای غیرمنتظره رخ داد. لطفاً دوباره تلاش کنید.',
      'timeout': 'زمان اتصال به سرور به پایان رسید. اتصال اینترنت خود را بررسی کنید.',
      'connectionError': 'اتصال به سرور برقرار نشد. لطفاً اتصال اینترنت خود را بررسی کنید.',
      'cancelled': 'درخواست لغو شد.',
      'badCertificate': 'گواهی امنیتی سرور معتبر نیست.',
      'transformError': 'خطای غیرمنتظره در پردازش داده‌های شبکه.',
      'badRequest': 'درخواست نامعتبر است. لطفاً ورودی‌ها را بررسی کنید.',
      'unauthorized': 'ایمیل یا رمز عبور اشتباه است، یا نشست شما منقضی شده.',
      'forbidden': 'شما اجازهٔ انجام این عملیات را ندارید.',
      'notFound': 'منبع درخواستی یافت نشد.',
      'conflict': 'این اطلاعات قبلاً ثبت شده است.',
      'rateLimited': 'سهمیهٔ رایگان هوش مصنوعی موقتاً تمام شده است. لطفاً چند دقیقهٔ دیگر دوباره تلاش کنید.',
      'serverError': 'خطای داخلی سرور. لطفاً کمی بعد دوباره تلاش کنید.',
      'unknownServerError': 'خطای ناشناخته در ارتباط با سرور.',
      'invalidResponse': 'پاسخ نامعتبر از سرور دریافت شد.',
    },
    'en': {
      'unexpectedError': 'An unexpected error occurred. Please try again.',
      'timeout': 'The connection to the server timed out. Please check your internet connection.',
      'connectionError': 'Could not connect to the server. Please check your internet connection.',
      'cancelled': 'The request was cancelled.',
      'badCertificate': 'The server\'s security certificate is not valid.',
      'transformError': 'An unexpected error occurred while processing network data.',
      'badRequest': 'The request is invalid. Please check your input.',
      'unauthorized': 'Incorrect email or password, or your session has expired.',
      'forbidden': 'You are not allowed to perform this action.',
      'notFound': 'The requested resource was not found.',
      'conflict': 'This information has already been registered.',
      'rateLimited': 'The free AI quota is temporarily exhausted. Please try again in a few minutes.',
      'serverError': 'Internal server error. Please try again shortly.',
      'unknownServerError': 'An unknown error occurred while communicating with the server.',
      'invalidResponse': 'An invalid response was received from the server.',
    },
    'ps': {
      'unexpectedError': 'یوه غیرمنتظره تېروتنه رامنځته شوه. مهرباني وکړئ بیا هڅه وکړئ.',
      'timeout': 'د سرور سره د اړیکې وخت پای ته ورسید. د خپل انټرنیټ اړیکه وګورئ.',
      'connectionError': 'له سرور سره اړیکه ونه نیول شوه. مهرباني وکړئ د خپل انټرنیټ اړیکه وګورئ.',
      'cancelled': 'غوښتنه لغوه شوه.',
      'badCertificate': 'د سرور امنیتي سند معتبر نه دی.',
      'transformError': 'د شبکې د معلوماتو په پروسس کې غیرمنتظره تېروتنه.',
      'badRequest': 'غوښتنه ناسمه ده. مهرباني وکړئ ننوتلي معلومات وګورئ.',
      'unauthorized': 'بریښنالیک یا پټنوم ناسم دی، یا ستاسو ناسته ختمه شوې.',
      'forbidden': 'تاسو د دې کړنې د ترسره کولو اجازه نه لرئ.',
      'notFound': 'غوښتل شوی سرچینه ونه موندل شوه.',
      'conflict': 'دا معلومات دمخه ثبت شوي دي.',
      'rateLimited': 'د مصنوعي هوښیارتیا وړیا ونډه د اوس لپاره پای ته ورسېده. څو دقیقې وروسته بیا هڅه وکړئ.',
      'serverError': 'د سرور داخلي تېروتنه. مهرباني وکړئ لږ وروسته بیا هڅه وکړئ.',
      'unknownServerError': 'له سرور سره په اړیکه کې ناڅرګنده تېروتنه.',
      'invalidResponse': 'له سرور نه ناسم ځواب ترلاسه شو.',
    },
    'fr': {
      'unexpectedError': 'Une erreur inattendue s\'est produite. Veuillez réessayer.',
      'timeout': 'Le délai de connexion au serveur a expiré. Vérifiez votre connexion Internet.',
      'connectionError': 'Impossible de se connecter au serveur. Vérifiez votre connexion Internet.',
      'cancelled': 'La requête a été annulée.',
      'badCertificate': 'Le certificat de sécurité du serveur n\'est pas valide.',
      'transformError': 'Erreur inattendue lors du traitement des données réseau.',
      'badRequest': 'La requête est invalide. Veuillez vérifier les informations saisies.',
      'unauthorized': 'E-mail ou mot de passe incorrect, ou votre session a expiré.',
      'forbidden': 'Vous n\'êtes pas autorisé à effectuer cette action.',
      'notFound': 'La ressource demandée est introuvable.',
      'conflict': 'Ces informations sont déjà enregistrées.',
      'rateLimited': "Le quota gratuit d'IA est temporairement épuisé. Veuillez réessayer dans quelques minutes.",
      'serverError': 'Erreur interne du serveur. Veuillez réessayer sous peu.',
      'unknownServerError': 'Erreur inconnue lors de la communication avec le serveur.',
      'invalidResponse': 'Une réponse invalide a été reçue du serveur.',
    },
  };

  String _t(String key) => _i18n[localeCode]?[key] ?? _i18n['fa']![key]!;

  /// [dio] فقط برای تست تزریق می‌شود؛ در Production خالی بگذارید تا نمونهٔ
  /// پیکربندی‌شده ساخته شود.
  ApiClient({
    String baseUrl = kApiBaseUrl,
    TokenProvider? tokenProvider,
    UnauthorizedCallback? onUnauthorized,
    Dio? dio,
    bool enableLogging = false,
    this.localeCode = 'fa',
  })  : _tokenProvider = tokenProvider,
        _onUnauthorized = onUnauthorized {
    _dio = dio ??
        Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: const Duration(seconds: 15),
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            responseType: ResponseType.json,
            contentType: Headers.jsonContentType,
            headers: {
              'Accept': 'application/json',
            },
            // خودمان بر اساس statusCode تصمیم می‌گیریم تا کنترل کامل روی
            // نگاشت خطا داشته باشیم (به‌جای پرتاب خودکار Dio).
            validateStatus: (status) => status != null && status < 300,
          ),
        );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _tokenProvider?.call();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          // 401 → به لایهٔ بالاتر خبر بده (Logout/Refresh) اما همچنان خطا را عبور بده.
          if (error.response?.statusCode == 401) {
            _onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );

    if (enableLogging) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
      ));
    }
  }

  /// دسترسی خام به Dio (برای موارد پیشرفته مثل آپلود فایل چندبخشی — بخش ۱۱).
  Dio get raw => _dio;

  // ───────────────────────── متدهای استاندارد HTTP ─────────────────────────

  /// GET — بدنهٔ پاسخ (JSON پارس‌شده) را برمی‌گرداند.
  Future<dynamic> get(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) =>
      _request(() => _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ));

  /// POST — [data] معمولاً `Map<String, dynamic>` است.
  Future<dynamic> post(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) =>
      _request(() => _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ));

  /// PUT — به‌روزرسانی کامل یک منبع.
  Future<dynamic> put(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) =>
      _request(() => _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ));

  /// PATCH — به‌روزرسانی جزئی (بسیاری از Endpointهای Admin بخش ۱۹.۷).
  Future<dynamic> patch(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) =>
      _request(() => _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ));

  /// DELETE — حذف یک منبع.
  Future<dynamic> delete(
      String path, {
        Object? data,
        Map<String, dynamic>? queryParameters,
        Options? options,
        CancelToken? cancelToken,
      }) =>
      _request(() => _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      ));

  // ───────────────────────── Endpointهای صریح Auth ─────────────────────────

  /// ثبت‌نام کاربر — `POST /auth/register` (بخش ۱۹.۱ / ۳ب.۲ سند).
  ///
  /// [userData] باید کلیدهای مورد انتظار Backend را داشته باشد، مثلاً:
  /// ```dart
  /// {
  ///   "firstName": "...", "lastName": "...", "email": "...",
  ///   "phone": "+93...", "password": "...", "dateOfBirth": "2011-03-14",
  ///   "currentGrade": 7, "province": "کابل", "inviteCode": "ABC123"
  /// }
  /// ```
  /// خروجی موفق: `Map<String, dynamic>` بدنهٔ پاسخ (شامل user و توکن‌ها).
  /// در صورت خطا `ApiException` پرتاب می‌شود (مثلاً 403 برای Invite Code
  /// نامعتبر، 409 برای ایمیل تکراری).
  Future<Map<String, dynamic>> registerUser(Map<String, dynamic> userData) async {
    final data = await post('/auth/register', data: userData);
    return _asMap(data);
  }

  /// ورود — `POST /auth/login`. خروجی شامل `accessToken`/`refreshToken` و `user`.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await post('/auth/login', data: {
      'email': email,
      'password': password,
    });
    return _asMap(data);
  }

  /// تمدید Token — `POST /auth/refresh` (بخش ۳.۳ — Refresh Rotation).
  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final data = await post('/auth/refresh', data: {'refreshToken': refreshToken});
    return _asMap(data);
  }

  /// آپلود بایت‌های خام (مثل عکس پروفایل) با Content-Type مشخص.
  Future<Map<String, dynamic>> uploadBytes(
    String path,
    List<int> bytes,
    String contentType,
  ) async {
    final data = await _request(() => _dio.post(
          path,
          data: Stream<List<int>>.value(bytes),
          options: Options(
            contentType: contentType,
            headers: {Headers.contentLengthHeader: bytes.length},
          ),
        ));
    return _asMap(data);
  }

  // ───────────────────────── هستهٔ اجرا + نگاشت خطا ─────────────────────────

  /// اجرای یک درخواست و ترجمهٔ هر `DioException` به `ApiException`.
  Future<dynamic> _request(Future<Response<dynamic>> Function() run) async {
    try {
      final response = await run();
      return response.data;
    } on DioException catch (e) {
      throw _mapDioError(e);
    } catch (e) {
      throw ApiException(
        message: _t('unexpectedError'),
        type: ApiErrorType.unknown,
      );
    }
  }

  ApiException _mapDioError(DioException e) {
    // ۱) خطاهای زمان/اتصال (بدون پاسخ سرور).
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: _t('timeout'),
          type: ApiErrorType.timeout,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: _t('connectionError'),
          type: ApiErrorType.network,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: _t('cancelled'),
          type: ApiErrorType.network,
        );
      case DioExceptionType.badCertificate:
        return ApiException(
          message: _t('badCertificate'),
          type: ApiErrorType.network,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break; // پایین پردازش می‌شود.
      case DioExceptionType.transformTimeout:
        return ApiException(
          message: _t('transformError'),
          type: ApiErrorType.unknown,
          code: 'TRANSFORM_TIMEOUT',
        );
    }

    // ۲) خطاهای دارای پاسخ HTTP.
    final status = e.response?.statusCode;
    final serverCode = _extractServerCode(e.response?.data);
    final serverMsg = _extractServerMessage(e.response?.data);

    switch (status) {
      case 400:
        return ApiException(
          message: serverMsg ?? _t('badRequest'),
          type: ApiErrorType.badRequest,
          statusCode: 400,
          code: serverCode,
        );
      case 401:
        return ApiException(
          message: serverMsg ?? _t('unauthorized'),
          type: ApiErrorType.unauthorized,
          statusCode: 401,
          code: serverCode,
        );
      case 403:
        return ApiException(
          message: serverMsg ?? _t('forbidden'),
          type: ApiErrorType.forbidden,
          statusCode: 403,
          code: serverCode,
        );
      case 404:
        return ApiException(
          message: serverMsg ?? _t('notFound'),
          type: ApiErrorType.notFound,
          statusCode: 404,
          code: serverCode,
        );
      case 409:
        return ApiException(
          message: serverMsg ?? _t('conflict'),
          type: ApiErrorType.conflict,
          statusCode: 409,
          code: serverCode,
        );
      case 429:
        return ApiException(
          message: serverMsg ?? _t('rateLimited'),
          type: ApiErrorType.rateLimited,
          statusCode: 429,
          code: serverCode,
        );
      default:
        if (status != null && status >= 500) {
          return ApiException(
            message: serverMsg ?? _t('serverError'),
            type: ApiErrorType.server,
            statusCode: status,
            code: serverCode,
          );
        }
        return ApiException(
          message: serverMsg ?? _t('unknownServerError'),
          type: ApiErrorType.unknown,
          statusCode: status,
          code: serverCode,
        );
    }
  }

  /// استخراج `error.code` از قرارداد خطای بخش ۱۹.۱۰:
  /// `{ "success": false, "error": { "code": "...", "message_fa": "..." } }`
  String? _extractServerCode(dynamic body) {
    if (body is Map) {
      final err = body['error'];
      if (err is Map && err['code'] != null) return err['code'].toString();
      if (body['code'] != null) return body['code'].toString();
    }
    return null;
  }

  /// استخراج پیام محلی‌شدهٔ خطا از بدنهٔ پاسخ سرور، بر اساس زبان جاری اپ
  /// (`localeCode`). سرور (طبق قرارداد بخش ۱۹.۱۰) هر ۴ زبان را همزمان در
  /// `message_fa`/`message_en`/`message_ps`/`message_fr` برمی‌گرداند؛ این
  /// متد اول فیلد متناظر با زبان انتخابی کاربر را امتحان می‌کند و در صورت
  /// نبود (مثلاً نسخهٔ قدیمی‌تر بک‌اند که فقط fa/en دارد)، به فارسی، بعد
  /// انگلیسی و در نهایت هر پیام موجود دیگر برمی‌گردد — تا هرگز پیام خالی
  /// به کاربر نشان داده نشود.
  String? _extractServerMessage(dynamic body) {
    Map? err;
    if (body is Map) {
      final e = body['error'];
      err = e is Map ? e : body;
    }
    if (err == null) {
      if (body is String && body.trim().isNotEmpty) return body;
      return null;
    }
    final localizedKey = switch (localeCode) {
      'en' => 'message_en',
      'ps' => 'message_ps',
      'fr' => 'message_fr',
      _ => 'message_fa',
    };
    for (final key in [localizedKey, 'message_fa', 'message', 'message_en', 'message_ps', 'message_fr']) {
      final v = err[key];
      if (v != null && v.toString().trim().isNotEmpty) return v.toString();
    }
    return null;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw ApiException(
      message: _t('invalidResponse'),
      type: ApiErrorType.unknown,
    );
  }

  /// آزادسازی منابع (در صورت نگهداری چرخهٔ عمر توسط DI).
  void close({bool force = false}) => _dio.close(force: force);
}