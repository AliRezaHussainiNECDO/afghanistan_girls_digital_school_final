import 'package:dartz/dartz.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/usecase/usecase.dart';
import 'package:equatable/equatable.dart';
import '../entities/app_user.dart';
import '../repositories/auth_repository.dart';

class LoginParams extends Equatable {
  final String email;
  final String password;
  const LoginParams({required this.email, required this.password});
  @override
  List<Object?> get props => [email, password];
}

class LoginUseCase implements UseCase<AppUser, LoginParams> {
  final AuthRepository repository;
  LoginUseCase(this.repository);

  @override
  Future<Either<Failure, AppUser>> call(LoginParams params) {
    return repository.login(email: params.email, password: params.password);
  }
}

class RegisterStudentParams extends Equatable {
  final String firstName;
  final String lastName;
  final String dateOfBirth;
  final String email;
  final String phone;
  final String password;
  final int currentGrade;
  final String province;
  final String inviteCode;

  const RegisterStudentParams({
    required this.firstName,
    required this.lastName,
    required this.dateOfBirth,
    required this.email,
    required this.phone,
    required this.password,
    required this.currentGrade,
    required this.province,
    required this.inviteCode,
  });

  @override
  List<Object?> get props =>
      [firstName, lastName, dateOfBirth, email, phone, password, currentGrade, province, inviteCode];
}

/// طبق بخش ۳.۱/۳ب.۲ سند: ثبت‌نام دانش‌آموز اکنون نیازمند Invite Code معتبر است.
class RegisterStudentUseCase implements UseCase<AppUser, RegisterStudentParams> {
  final AuthRepository repository;
  RegisterStudentUseCase(this.repository);

  @override
  Future<Either<Failure, AppUser>> call(RegisterStudentParams params) {
    return repository.registerStudent(
      firstName: params.firstName,
      lastName: params.lastName,
      dateOfBirth: params.dateOfBirth,
      email: params.email,
      phone: params.phone,
      password: params.password,
      currentGrade: params.currentGrade,
      province: params.province,
      inviteCode: params.inviteCode,
    );
  }
}

class RegisterParentParams extends Equatable {
  final String fullName;
  final String email;
  final String phone;
  final String password;

  const RegisterParentParams({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
  });

  @override
  List<Object?> get props => [fullName, email, phone, password];
}

class RegisterParentUseCase implements UseCase<AppUser, RegisterParentParams> {
  final AuthRepository repository;
  RegisterParentUseCase(this.repository);

  @override
  Future<Either<Failure, AppUser>> call(RegisterParentParams params) {
    return repository.registerParent(
      fullName: params.fullName,
      email: params.email,
      phone: params.phone,
      password: params.password,
    );
  }
}

/// ثبت‌نام استاد سمینار (بخش ۲.۲: افزودن استاد در انحصار مدیر است، پس
/// ثبت‌نام فقط با کد دعوت ساخته‌شده توسط مدیر ممکن است).
class RegisterInstructorParams extends Equatable {
  final String fullName;
  final String email;
  final String phone;
  final String password;

  /// تخصص/رشتهٔ تدریس (مثلاً «مهارت‌های زندگی»، «کمپیوتر») — معلومات ضروری
  /// برای برگزاری سمینار.
  final String specialty;

  /// سابقهٔ تدریس/معرفی کوتاه.
  final String bio;
  final String inviteCode;

  const RegisterInstructorParams({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.password,
    required this.specialty,
    required this.bio,
    required this.inviteCode,
  });

  @override
  List<Object?> get props => [fullName, email, phone, specialty, inviteCode];
}

class RegisterInstructorUseCase implements UseCase<AppUser, RegisterInstructorParams> {
  final AuthRepository repository;
  RegisterInstructorUseCase(this.repository);

  @override
  Future<Either<Failure, AppUser>> call(RegisterInstructorParams params) {
    return repository.registerInstructor(
      fullName: params.fullName,
      email: params.email,
      phone: params.phone,
      password: params.password,
      specialty: params.specialty,
      bio: params.bio,
      inviteCode: params.inviteCode,
    );
  }
}

class ForgotPasswordUseCase implements UseCase<Unit, String> {
  final AuthRepository repository;
  ForgotPasswordUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(String email) {
    return repository.forgotPassword(email);
  }
}

class LogoutUseCase implements UseCase<Unit, NoParams> {
  final AuthRepository repository;
  LogoutUseCase(this.repository);

  @override
  Future<Either<Failure, Unit>> call(NoParams params) {
    return repository.logout();
  }
}
