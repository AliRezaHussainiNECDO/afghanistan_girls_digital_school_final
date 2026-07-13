/// پیاده‌سازی Concrete از Interface لایهٔ domain (بخش ۲۴.۳).

library;
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';

import '../../../../../core/errors/failures.dart';
import '../../domain/entities/student_entities.dart';
import '../../domain/repositories/student_management_repository.dart';
import '../datasources/remote/student_management_remote_datasource.dart';

class StudentManagementRepositoryImpl implements StudentManagementRepository {
  final StudentManagementRemoteDataSource remote;
  const StudentManagementRepositoryImpl(this.remote);

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() run) async {
    try {
      return Right(await run());
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        return const Left(NetworkFailure());
      }
      if (e.response?.statusCode == 403) return const Left(PermissionFailure());
      return Left(ServerFailure(
          e.response?.data?['message']?.toString() ?? 'خطای سرور رخ داد',
          code: e.response?.statusCode?.toString()));
    } catch (_) {
      return const Left(ServerFailure('خطای سرور رخ داد'));
    }
  }

  @override
  Future<Either<Failure, PagedStudents>> getStudents(
          StudentListFilter filter) =>
      _guard(() => remote.fetchStudents(filter));

  @override
  Future<Either<Failure, StudentDetail>> getStudentDetail(String studentId) =>
      _guard(() => remote.fetchStudentDetail(studentId));

  @override
  Future<Either<Failure, AiTeacherReport>> getAiReport(String studentId) =>
      _guard(() => remote.fetchAiReport(studentId));

  @override
  Future<Either<Failure, void>> updateStatus(
          String studentId, AccountStatus status, String reason) =>
      _guard(() => remote.patchStatus(studentId, status, reason));

  @override
  Future<Either<Failure, void>> softDelete(String studentId, String reason) =>
      _guard(() => remote.softDelete(studentId, reason));

  @override
  Future<Either<Failure, void>> sendPasswordResetLink(String studentId) =>
      _guard(() => remote.sendPasswordResetLink(studentId));
}
