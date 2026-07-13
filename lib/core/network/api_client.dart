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
  defaultValue: 'https://api.afghanistangirlsdigitalschool.org/api/v1',
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

  /// [dio] فقط برای تست تزریق می‌شود؛ در Production خالی بگذارید تا نمونهٔ
  /// پیکربندی‌شده ساخته شود.
  ApiClient({
    String baseUrl = kApiBaseUrl,
    TokenProvider? tokenProvider,
    UnauthorizedCallback? onUnauthorized,
    Dio? dio,
    bool enableLogging = false,
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
      throw const ApiException(
        message: 'خطای غیرمنتظره رخ داد. لطفاً دوباره تلاش کنید.',
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
        return const ApiException(
          message: 'زمان اتصال به سرور به پایان رسید. اتصال اینترنت خود را بررسی کنید.',
          type: ApiErrorType.timeout,
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'اتصال به سرور برقرار نشد. لطفاً اتصال اینترنت خود را بررسی کنید.',
          type: ApiErrorType.network,
        );
      case DioExceptionType.cancel:
        return const ApiException(
          message: 'درخواست لغو شد.',
          type: ApiErrorType.network,
        );
      case DioExceptionType.badCertificate:
        return const ApiException(
          message: 'گواهی امنیتی سرور معتبر نیست.',
          type: ApiErrorType.network,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break; // پایین پردازش می‌شود.
      case DioExceptionType.transformTimeout:
      default:
        return const ApiException(
          message: 'خطای غیرمنتظره در پردازش داده‌های شبکه.',
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
          message: serverMsg ?? 'درخواست نامعتبر است. لطفاً ورودی‌ها را بررسی کنید.',
          type: ApiErrorType.badRequest,
          statusCode: 400,
          code: serverCode,
        );
      case 401:
        return ApiException(
          message: serverMsg ?? 'ایمیل یا رمز عبور اشتباه است، یا نشست شما منقضی شده.',
          type: ApiErrorType.unauthorized,
          statusCode: 401,
          code: serverCode,
        );
      case 403:
        return ApiException(
          message: serverMsg ?? 'شما اجازهٔ انجام این عملیات را ندارید.',
          type: ApiErrorType.forbidden,
          statusCode: 403,
          code: serverCode,
        );
      case 404:
        return ApiException(
          message: serverMsg ?? 'منبع درخواستی یافت نشد.',
          type: ApiErrorType.notFound,
          statusCode: 404,
          code: serverCode,
        );
      case 409:
        return ApiException(
          message: serverMsg ?? 'این اطلاعات قبلاً ثبت شده است.',
          type: ApiErrorType.conflict,
          statusCode: 409,
          code: serverCode,
        );
      default:
        if (status != null && status >= 500) {
          return ApiException(
            message: serverMsg ?? 'خطای داخلی سرور. لطفاً کمی بعد دوباره تلاش کنید.',
            type: ApiErrorType.server,
            statusCode: status,
            code: serverCode,
          );
        }
        return ApiException(
          message: serverMsg ?? 'خطای ناشناخته در ارتباط با سرور.',
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

  /// استخراج پیام فارسی (یا انگلیسی) از بدنهٔ خطای سرور.
  String? _extractServerMessage(dynamic body) {
    if (body is Map) {
      final err = body['error'];
      if (err is Map) {
        return (err['message_fa'] ?? err['message'] ?? err['message_en'])?.toString();
      }
      return (body['message_fa'] ?? body['message'] ?? body['message_en'])?.toString();
    }
    if (body is String && body.trim().isNotEmpty) return body;
    return null;
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ApiException(
      message: 'پاسخ نامعتبر از سرور دریافت شد.',
      type: ApiErrorType.unknown,
    );
  }

  /// آزادسازی منابع (در صورت نگهداری چرخهٔ عمر توسط DI).
  void close({bool force = false}) => _dio.close(force: force);
}