import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/api_client.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

/// پیاده‌سازی Repository احراز هویت.
///
/// به قرارداد مشترک `AuthDataSource` وابسته است، نه به یک پیاده‌سازی مشخص —
/// بنابراین بدون هیچ تغییری با `AuthMockDataSource` (فاز ۱) یا
/// `AuthRemoteDataSource` (فاز ۲ — Cloudflare Worker) کار می‌کند. انتخاب یکی
/// از این دو فقط در `auth_providers.dart` انجام می‌شود.
///
/// وظیفهٔ کلیدی این لایه: ترجمهٔ خطاهای پایین‌دستی (`ApiException` از شبکه یا
/// `Failure` از Mock) به انواع `Failure` دامنه (بخش ۲۴.۱ سند) تا لایهٔ UI
/// همیشه یک نوع خطای یکنواخت ببیند.
class AuthRepositoryImpl implements AuthRepository {
  final AuthDataSource dataSource;

  AuthRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, AppUser>> login({
    required String email,
    required String password,
  }) {
    return _guard(() => dataSource.login(email, password));
  }

  @override
  Future<Either<Failure, AppUser>> registerStudent({
    required String firstName,
    required String lastName,
    required String dateOfBirth,
    required String email,
    required String phone,
    required String password,
    required int currentGrade,
    required String province,
    required String inviteCode,
  }) {
    return _guard(() => dataSource.registerStudent(
          firstName: firstName,
          lastName: lastName,
          email: email,
          inviteCode: inviteCode,
          currentGrade: currentGrade,
          phone: phone,
          province: province,
          dateOfBirth: dateOfBirth,
          password: password,
        ));
  }

  @override
  Future<Either<Failure, AppUser>> registerParent({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) {
    return _guard(() => dataSource.registerParent(
          fullName: fullName,
          email: email,
          phone: phone,
          password: password,
        ));
  }

  @override
  Future<Either<Failure, AppUser>> registerInstructor({
    required String fullName,
    required String email,
    required String phone,
    required String password,
    required String specialty,
    required String bio,
    required String inviteCode,
  }) {
    return _guard(() => dataSource.registerInstructor(
          fullName: fullName,
          email: email,
          phone: phone,
          specialty: specialty,
          bio: bio,
          inviteCode: inviteCode,
          password: password,
        ));
  }

  @override
  Future<Either<Failure, Unit>> forgotPassword(String email) async {
    try {
      await dataSource.forgotPassword(email);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await dataSource.resetPassword(email: email, code: code, newPassword: newPassword);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> resendVerification(String email) async {
    try {
      await dataSource.resendVerification(email);
      return const Right(unit);
    } catch (_) {
      // پاسخ همیشه عمومی است؛ شکست شبکه هم نباید UI را بشکند.
      return const Right(unit);
    }
  }

  @override
  Future<AppUser?> restoreSession() async {
    try {
      return await dataSource.restoreSession();
    } catch (_) {
      return null; // هر خطایی هنگام بازیابی = نشست نامعتبر؛ کاربر وارد می‌شود.
    }
  }

  @override
  Future<Either<Failure, String?>> uploadAvatar(List<int> bytes, String contentType) async {
    try {
      return Right(await dataSource.uploadAvatar(bytes, contentType));
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, AppUser>> updateProfile({
    required String firstName,
    required String lastName,
  }) {
    return _guard(() => dataSource.updateProfile(firstName: firstName, lastName: lastName));
  }

  @override
  Future<Either<Failure, Unit>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await dataSource.changePassword(currentPassword: currentPassword, newPassword: newPassword);
      return const Right(unit);
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, Unit>> logout() async {
    try {
      await dataSource.logout();
      return const Right(unit);
    } catch (_) {
      // خروج نباید هرگز شکست بخورد؛ نشست محلی در هر حال پاک می‌شود.
      return const Right(unit);
    }
  }

  @override
  Future<AppUser?> getCurrentUser() async => dataSource.currentUser;

  // ─────────────────────────── کمک‌کننده‌ها ─────────────────────────────

  /// اجرای یک عملیات Auth و تبدیل هر استثنا به `Either<Failure, AppUser>`.
  Future<Either<Failure, AppUser>> _guard(
      Future<AppUser> Function() run) async {
    try {
      return Right(await run());
    } on ApiException catch (e) {
      return Left(_mapApi(e));
    } on Failure catch (f) {
      // پیام‌های خوانای Mock (کد نامعتبر/مصرف‌شده/منقضی) از قبل Failure هستند.
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  /// نگاشت `ApiException` شبکه به `Failure` دامنه.
  Failure _mapApi(ApiException e) {
    switch (e.type) {
      case ApiErrorType.timeout:
      case ApiErrorType.network:
        return NetworkFailure(e.message);
      case ApiErrorType.badRequest:
        return ValidationFailure(e.message);
      case ApiErrorType.forbidden:
        // مثلاً 403 INVALID_INVITE_CODE (بخش ۳ب.۲) یا نبود مجوز RBAC.
        return ServerFailure(e.message, code: e.code);
      case ApiErrorType.unauthorized:
      case ApiErrorType.conflict:
      case ApiErrorType.notFound:
      case ApiErrorType.server:
      case ApiErrorType.unknown:
        return ServerFailure(e.message, code: e.code);
    }
  }
}
